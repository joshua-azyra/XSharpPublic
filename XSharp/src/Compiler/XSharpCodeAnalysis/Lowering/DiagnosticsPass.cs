﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
#nullable disable

using LanguageService.CodeAnalysis.XSharp.SyntaxParser;
using Microsoft.CodeAnalysis.CSharp.Symbols;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Roslyn.Utilities;

namespace Microsoft.CodeAnalysis.CSharp
{
    /// <summary>
    /// This pass detects and reports diagnostics that do not affect lambda convertibility.
    /// This part of the partial class focuses on expression and operator warnings.
    /// </summary>
    internal sealed partial class DiagnosticsPass
    {
        private void XsCheckCompoundAssignmentOperator(BoundCompoundAssignmentOperator node)
        {
            var syntax = node.Syntax;
            if (syntax == null || node.WasCompilerGenerated)
                return;
            var leftType = node.Left.Type;
            var rightType = node.Right.Type;
            if (node.Right is BoundConversion bcv)
            {
                rightType = bcv.Operand.Type;
            }
            GenerateWarning(rightType, leftType, node);
        }

        private void GenerateWarning(TypeSymbol sourceType, TypeSymbol targetType, BoundNode node)
        {

            var syntax = node.Syntax;
            if (node.IsExpressionWithNumericConstant() || syntax.XIsExplicitTypeCastInCode)
            {
                node.DisableWarnings();
            }
            if (!syntax.XNoWarning && !syntax.XNoTypeWarning && !Equals(sourceType, targetType) && !syntax.XContainsGeneratedExpression
                && sourceType.IsXNumericType() && targetType.IsXNumericType())
            {
                var errCode = ErrorCode.Void;
                if (_compilation.Options.HasOption(CompilerOption.Vo4, syntax))
                {
                    // when converting from fractional to another type precision may be lost
                    errCode = LocalRewriter.DetermineConversionError(sourceType, targetType);
                }
                if (errCode != ErrorCode.Void)
                {
                    Error(errCode, node, sourceType, targetType);
                }
            }
        }
        private void XsCheckMemberAccess(BoundNode node, XSharpParser.AccessMemberContext amc, Symbol symbol)
        {
            var contType = symbol.ContainingType;
            if (!node.HasErrors())
            {
                switch (amc.Op.Type)
                {
                    case XSharpLexer.COLONCOLON:
                        if (_compilation.Options.Dialect != XSharpDialect.XPP && symbol.IsStatic)
                        {
                            // XPP allows static and instance, other dialects only instance
                            Error(ErrorCode.WRN_ColonForStaticMember, node, symbol);
                        }
                        break;
                    case XSharpLexer.DOT:
                        if (symbol.IsStatic || contType.IsVoStructOrUnion() ||
                            _compilation.Options.HasOption(CompilerOption.AllowDotForInstanceMembers, node.Syntax)
                            )
                        {
                            ; // Ok
                        }
                        else
                        {
                            Error(ErrorCode.WRN_DotForInstanceMember, node, symbol);
                        }
                        break;
                    case XSharpLexer.COLON:
                        if (symbol.IsStatic && !contType.IsFunctionsClass()) // For late bound code where member access is redirected to function
                        {
                            Error(ErrorCode.WRN_ColonForStaticMember, node, symbol);
                        }
                        break;
                    default:
                        RoslynDebug.Assert(false, $"Unexpected MemberAccess token  '{amc.Op.Text}'");
                        break;
                }
            }
        }

        private void XsVisitFieldAccess(BoundFieldAccess node)
        {
            if (node.Syntax?.XNode is XSharpParser.AccessMemberContext amc)
            {
                XsCheckMemberAccess(node, amc, node.FieldSymbol);
            }
            return;
        }
        private void XsVisitPropertyAccess(BoundPropertyAccess node)
        {
            if (node.Syntax?.XNode is XSharpParser.AccessMemberContext amc)
            {
                XsCheckMemberAccess(node, amc, node.PropertySymbol);
            }
            return;
        }
        private void XsVisitIndexerAccess(BoundIndexerAccess node)
        {
            if (node.Syntax?.XNode is XSharpParser.AccessMemberContext amc)
            {
                XsCheckMemberAccess(node, amc, node.Indexer);
            }
            return;
        }
        private void XsVisitCall(BoundCall node)
        {
            if (node.Syntax?.XNode is XSharpParser.MethodCallContext mc && mc.Expr is XSharpParser.AccessMemberContext amc)
            {
                if (!node.Method.IsExtensionMethod && !node.Method.IsOperator())
                {
                    XsCheckMemberAccess(node, amc, node.Method);
                }
                return;
            }
        }
        public void XsVisitEventAssignmentOperator(BoundEventAssignmentOperator node)
        {
            if (node.Syntax?.XNode is XSharpParser.AssignmentExpressionContext aec &&
                aec.Left is XSharpParser.AccessMemberContext amc)
            {
                XsCheckMemberAccess(node, amc, node.Event);
            }
            return;
        }
        public void XsVisitEventAccess(BoundEventAccess node)
        {
            if (node.Syntax?.XNode is XSharpParser.AccessMemberContext amc)
            {
                XsCheckMemberAccess(node, amc, node.EventSymbol);
            }
            return;
        }
        private void XsCheckConversion(BoundConversion node)
        {
            var syntax = node.Syntax;
            var sourceType = node.Operand.Type;
            var targetType = node.Type;
            if (syntax is BinaryExpressionSyntax binexp)
            {
                // determine original expression type
                // Roslyn will change a Int32 + UIn32
                // to an addition of 2 Int64 values
                // but we want the original UInt32 value for the warning message
                if (node.Operand is BoundBinaryOperator binop)
                {
                    var right = binop.Right;
                    if (right is BoundConversion bcv)
                    {
                        right = bcv.Operand;
                    }
                    sourceType = right.Type;
                }
            }
            if (sourceType is null || targetType is null)
                return;
            if (sourceType.IsIntegralType() && targetType.IsPointerType())
            {
                VOCheckIntegerToPointer(node);
            }
            if (syntax == null || syntax.XIsExplicitTypeCastInCode || node.WasCompilerGenerated
                || node.ConstantValueOpt != null)
                return;
            GenerateWarning(sourceType, targetType, node);
        }
        private void VOCheckIntegerToPointer(BoundConversion node)
        {
            var srcType = node.Operand.Type;
            var platform = _compilation.Options.Platform;
            if (srcType.IsPointerType())
                return;
            switch (platform)
            {
                case Platform.X86:
                    if (srcType.SpecialType.SizeInBytes() > 4)
                    {
                        Error(ErrorCode.ERR_CantCastPtrInPlatform, node, srcType.ToDisplayString(), "x86");
                    }
                    else if (node.Syntax.XIsExplicitTypeCastInCode && srcType.SpecialType.SizeInBytes() != 4)
                    {
                        Error(ErrorCode.ERR_CantCastPtrInPlatform, node, srcType.ToDisplayString(), "x86");
                    }
                    break;
                case Platform.X64:
                    if (srcType.SpecialType.SizeInBytes() > 8)
                    {
                        Error(ErrorCode.ERR_CantCastPtrInPlatform, node, srcType.ToDisplayString(), "x64");
                    }
                    else if (node.Syntax.XIsExplicitTypeCastInCode && srcType.SpecialType.SizeInBytes() != 8)
                    {
                        Error(ErrorCode.ERR_CantCastPtrInPlatform, node, srcType.ToDisplayString(), "x86");
                    }
                    break;
                default:
                    string name = platform.ToString();
                    if (platform == Platform.AnyCpu32BitPreferred)
                        name = "AnyCpu";
                    Error(ErrorCode.ERR_CantCastPtrInAnyCpu, node, srcType.ToDisplayString(), name);
                    break;
            }
        }
    }
}

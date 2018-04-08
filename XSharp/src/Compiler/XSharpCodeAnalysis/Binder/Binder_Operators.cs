﻿/*
   Copyright 2016-2017 XSharp B.V.

Licensed under the X# compiler source code License, Version 1.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.xsharp.info/licenses

Unless required by applicable law or agreed to in writing, software
Distributed under the License is distributed on an "as is" basis,
without warranties or conditions of any kind, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Diagnostics;
using Microsoft.CodeAnalysis.CSharp.Symbols;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Roslyn.Utilities;
using LanguageService.CodeAnalysis.XSharp.SyntaxParser;
namespace Microsoft.CodeAnalysis.CSharp
{
    internal partial class Binder
    {
        private enum VOOperatorType
        {
            None = 0,
            CompareString,
            SingleEqualsString,
            SingleEqualsUsual,
            NotEqualsUsual,
            SubtractString,
            UsualOther,
            Shift,
            PSZCompare,
            SymbolCompare,
            LogicCompare
        }
        private BoundExpression BindVOCompareString(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
            BoundExpression left, BoundExpression right, ref int compoundStringLength)
        {
            MethodSymbol opMeth = null;
            TypeSymbol type;
            BoundCall opCall = null;

            if (Compilation.Options.IsDialectVO && this.Compilation.Options.VOStringComparisons)
            {
                // VO Style String Comparison
                type = Compilation.RuntimeFunctionsType();
                string methodName = XSharpFunctionNames.StringCompare ;
                var symbols = Binder.GetCandidateMembers(type, methodName, LookupOptions.MustNotBeInstance, this);
                if (symbols.Length == 1)
                {
                    opMeth = (MethodSymbol)symbols[0];
                    opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
                }
                else
                {
                    Error(diagnostics, ErrorCode.ERR_FeatureNotAvailableInDialect, node, "String Compare method " + type.Name + "." + methodName, Compilation.Options.Dialect.ToString());
                }
            }
            else
            {
                // Standard String Comparison using .Net String Compare
                type = this.GetSpecialType(SpecialType.System_String, diagnostics, node);
                TryGetSpecialTypeMember(Compilation, SpecialMember.System_String__Compare, node, diagnostics, out opMeth);
                opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
            }
            return BindSimpleBinaryOperator(node, diagnostics, opCall,
                new BoundLiteral(node, ConstantValue.Create((int)0), GetSpecialType(SpecialType.System_Int32, diagnostics, node)),
                ref compoundStringLength);
        }


        private BoundExpression BindVOSingleEqualsString(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
            BoundExpression left, BoundExpression right)
        {
            MethodSymbol opMeth = null;
            BoundExpression opCall = null;
            var type = Compilation.RuntimeFunctionsType();
            var methodName = XSharpFunctionNames.StringEquals; 
            var symbols = Binder.GetCandidateMembers(type, methodName, LookupOptions.MustNotBeInstance, this);
            if (symbols.Length == 1)
            {
                opMeth = (MethodSymbol)symbols[0];
                var stringType = Compilation.GetSpecialType(SpecialType.System_String);
                if (right.Type != stringType)
                {
                    right = CreateConversion(right, stringType, diagnostics);
                }
                if (left.Type != stringType)
                {
                    left = CreateConversion(left, stringType, diagnostics);
                }
                opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
            }
            else
            {
                Error(diagnostics, ErrorCode.ERR_FeatureNotAvailableInDialect, node, "String Equals (=) method " + type.Name + "." + methodName, Compilation.Options.Dialect.ToString());
            }
            return opCall;
        }

        private BoundExpression BindVOUsualOther(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
            BoundExpression left, BoundExpression right)
        {
            var usualType = Compilation.UsualType();
            BoundExpression opCall = null;
            ImmutableArray<Symbol> symbols;
            if (node.OperatorToken.Kind() == SyntaxKind.MinusToken)
                symbols = Binder.GetCandidateMembers(usualType, "op_Subtraction", LookupOptions.MustNotBeInstance, this);
            else
                symbols = Binder.GetCandidateMembers(usualType, "op_Addition", LookupOptions.MustNotBeInstance, this);
            if (symbols.Length == 1)
            {
                MethodSymbol opMeth = (MethodSymbol)symbols[0];
                if (right.Type != usualType)
                {
                    right = CreateConversion(right, usualType, diagnostics);
                }
                if (left.Type != usualType)
                {
                    left = CreateConversion(left, usualType, diagnostics);
                }
                opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
            }
            else
            {
                Error(diagnostics, ErrorCode.ERR_FeatureNotAvailableInDialect, node, "Usual - Date operators", Compilation.Options.Dialect.ToString());
            }
            return opCall;

        }

        private bool IsNullNode(BoundExpression node)
        {
            if (node.Syntax?.XNode != null)
            {
                var xnode = node.Syntax.XNode as XSharpParser.LiteralExpressionContext;
                if (xnode ==null && node.Syntax.XNode is XSharpParser.PrimaryExpressionContext)
                {
                    var pexp = node.Syntax.XNode as XSharpParser.PrimaryExpressionContext;
                    xnode = pexp.Expr as XSharpParser.LiteralExpressionContext;
                }
                if (xnode != null)
                {
                    switch (xnode.Literal.Token.Type)
                    {
                        case XSharpParser.NULL:
                        case XSharpParser.NULL_PTR:
                        case XSharpParser.NULL_PSZ:
                            return true;
                    }
                }
            }
            return false;
        }
        private BoundExpression BindVOPszCompare(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
                ref BoundExpression left, ref BoundExpression right)
        {
            var pszType = Compilation.PszType();
            if (right.Type != pszType)
            {
                if (IsNullNode(right))
                {
                    right = PszFromNull(right); 
                }
                else
                {
                    right = CreateConversion(right, pszType, diagnostics);
                }
            }
            if (left.Type != pszType)
            {
                if (IsNullNode(left))
                {
                    left = PszFromNull(left);
                }
                else
                {
                    left = CreateConversion(left, pszType, diagnostics);
                }
            }
            return null;
        }
        private BoundExpression BindVOSymbolCompare(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
                ref BoundExpression left, ref BoundExpression right)
        {
            var symType = Compilation.SymbolType();
            if (right.Type != symType)
            {
                right = CreateConversion(right, symType, diagnostics);
            }
            if (left.Type != symType)
            {
                left = CreateConversion(left, symType, diagnostics);
            }
            return null;
        }

        private BoundExpression BindVOLogicCompare(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
                ref BoundExpression left, ref BoundExpression right)
        {
            // Convert logic compare to integer compare where TRUE = 1 and FALSE = 0
            var intType = Compilation.GetSpecialType(SpecialType.System_Int32);
            var lit0 = new BoundLiteral(node, ConstantValue.Create(0), intType);
            var lit1 = new BoundLiteral(node, ConstantValue.Create(1), intType);
            left = new BoundConditionalOperator(node, left, lit1, lit0, null, intType);
            right = new BoundConditionalOperator(node, right, lit1, lit0, null, intType);
            return null;
        }

        private BoundExpression BindVOSingleEqualsUsual(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
             BoundExpression left, BoundExpression right)
        {
            MethodSymbol opMeth = null;
            BoundExpression opCall = null;
            var usualType = Compilation.UsualType();
            var methodName = XSharpFunctionNames.InExactEquals  ;
            var symbols = Binder.GetCandidateMembers(usualType, methodName, LookupOptions.MustNotBeInstance, this);
            if (symbols.Length == 2)
            {
                // There should be 2 overloads in VulcanRTFuncs:
                // public static bool __InexactEquals(__Usual ul, string uR)
                // public static bool __InexactEquals(__Usual uL, __Usual uR)
                // Switch to overload with string when RHS = STRING
                opMeth = (MethodSymbol)symbols[0];
                if (right.Type?.SpecialType == SpecialType.System_String)
                {
                    if (right.Type != opMeth.Parameters[0].Type)
                        opMeth = (MethodSymbol)symbols[1];
                }
                else
                {
                    // When RHS != USUAL then switch
                    if (opMeth.Parameters[0].Type != usualType)
                        opMeth = (MethodSymbol)symbols[1];
                    if (right.Type != usualType)
                    {
                        right = CreateConversion(right, usualType, diagnostics);
                    }
                }
                if (left.Type != usualType)
                {
                    left = CreateConversion(left, usualType, diagnostics);
                }

                opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
            }
            else
            {
                Error(diagnostics, ErrorCode.ERR_FeatureNotAvailableInDialect, node, "Usual Equals (=) method " + usualType.Name + "." + methodName, Compilation.Options.Dialect.ToString());
            }
            return opCall;
        }

        private BoundExpression BindVONotEqualsUsual(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
            BoundExpression left, BoundExpression right)
        {
            MethodSymbol opMeth = null;
            BoundExpression opCall = null;
            var usualType = Compilation.UsualType();
            var methodName = XSharpFunctionNames.InExactNotEquals ;
            var symbols = Binder.GetCandidateMembers(usualType, methodName, LookupOptions.MustNotBeInstance, this);
            if (symbols.Length == 2)
            {
                // There should be 2 overloads in VulcanRTFuncs:
                // public static bool __InexactNotEquals(__Usual ul, string uR)
                // public static bool __InexactNotEquals(__Usual uL, __Usual uR)
                // Switch to overload with string when RHS = STRING
                opMeth = (MethodSymbol)symbols[0];
                if (right.Type?.SpecialType == SpecialType.System_String)
                {
                    if (right.Type != opMeth.Parameters[0].Type)
                        opMeth = (MethodSymbol)symbols[1];
                }
                else
                {
                    // When RHS != USUAL then switch
                    if (opMeth.Parameters[0].Type != usualType)
                        opMeth = (MethodSymbol)symbols[1];
                    if (right.Type != usualType)
                    {
                        right = CreateConversion(right, usualType, diagnostics);
                    }
                }
                if (left.Type != usualType)
                {
                    left = CreateConversion(left, usualType, diagnostics);
                }
                opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
            }
            else
            {
                Error(diagnostics, ErrorCode.ERR_FeatureNotAvailableInDialect, node, "Usual NotEquals (!=) method " + usualType.Name + "." + methodName, Compilation.Options.Dialect.ToString());
            }
            return opCall;
        }

        private BoundExpression BindVOSubtractString(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
            BoundExpression left, BoundExpression right)
        {
            MethodSymbol opMeth = null;
            BoundExpression opCall = null;
            var type = Compilation.CompilerServicesType();
            var methodName = XSharpFunctionNames.StringSubtract ;
            var symbols = Binder.GetCandidateMembers(type, methodName, LookupOptions.MustNotBeInstance, this);
            if (symbols.Length == 1)
            {
                opMeth = (MethodSymbol)symbols[0];
                var stringType = Compilation.GetSpecialType(SpecialType.System_String);
                if (left.Type != stringType)
                {
                    left = CreateConversion(left, stringType, diagnostics);
                }
                if (right.Type != stringType)
                {
                    right = CreateConversion(right, stringType, diagnostics);
                }
                opCall = BoundCall.Synthesized(node, null, opMeth, left, right);
            }
            else
            {
                Error(diagnostics, ErrorCode.ERR_FeatureNotAvailableInDialect, node, "String Subtract method " + type.Name + "." + methodName, Compilation.Options.Dialect.ToString());
            }
            return opCall;
        }

        private BoundExpression BindVOBinaryOperator(BinaryExpressionSyntax node, DiagnosticBag diagnostics,
            ref BoundExpression left, ref BoundExpression right, ref int compoundStringLength, VOOperatorType opType)
        {
            switch (opType)
            {
                case VOOperatorType.SingleEqualsString:
                    return BindVOSingleEqualsString(node, diagnostics, left, right);
                case VOOperatorType.SingleEqualsUsual:
                    return BindVOSingleEqualsUsual(node, diagnostics, left, right);
                case VOOperatorType.NotEqualsUsual:
                    return BindVONotEqualsUsual(node, diagnostics, left, right);
                case VOOperatorType.SubtractString:
                    return BindVOSubtractString(node, diagnostics, left, right);
                case VOOperatorType.CompareString:
                    return BindVOCompareString(node, diagnostics, left, right, ref compoundStringLength);
                case VOOperatorType.UsualOther:
                    return BindVOUsualOther(node, diagnostics, left, right);
                case VOOperatorType.PSZCompare:
                    return BindVOPszCompare(node, diagnostics, ref left, ref right);
                case VOOperatorType.SymbolCompare:
                    return BindVOSymbolCompare(node, diagnostics, ref left, ref right);
                case VOOperatorType.LogicCompare:
                    return BindVOLogicCompare(node, diagnostics, ref left, ref right);

            }
            return null;
        }

        private VOOperatorType NeedsVOOperator(BinaryExpressionSyntax node, ref BoundExpression left, ref BoundExpression right)
        {
            // Check if a special XSharp binary operation is needed. This is needed when:
            //
            // Comparison  (>, >=, <, <=) operator and this.Compilation.Options.VOStringComparisons = true
            // Single Equals Operator and LHS and RHS are string                    // STRING = STRING
            // Single Equals Operator and LHS or RHS is USUAL                       // <any> = USUAL or USUAL = <any>
            // Not equals operator and LHS = USUAL and RHS is USUAL or STRING       // USUAL != STRING or USUAL != USUAL
            // Minus Operator and LHS and RHS is STRING                             // STRING - STRING
            // Minus Operator and LHS or  RHS is STRING and other side is USUAL     // STRING - USUAL or USUAL - STRING
            //
            VOOperatorType opType = VOOperatorType.None;
            XSharpParser.BinaryExpressionContext xnode;
            if (node.XNode is XSharpParser.CodeblockCodeContext)
                xnode = ((XSharpParser.CodeblockCodeContext)node.XNode).Expr as XSharpParser.BinaryExpressionContext;
            else
                xnode = node.XNode as XSharpParser.BinaryExpressionContext;
            if (xnode == null)  // this may happen for example for nodes generated in the transformation phase
                return opType;

            TypeSymbol leftType = left.Type;
            TypeSymbol rightType = right.Type;

            if (Compilation.Options.IsDialectVO)
            {
                var typeUsual = Compilation.UsualType();
                var typePSZ = Compilation.PszType();
                var typeSym = Compilation.SymbolType();
                NamedTypeSymbol typeDate;
                NamedTypeSymbol typeFloat;

                switch (xnode.Op.Type)
                {
                    case XSharpParser.EQ:
                        if (leftType?.SpecialType == SpecialType.System_String &&
                            (rightType?.SpecialType == SpecialType.System_String || rightType == typeUsual))
                        {
                            opType = VOOperatorType.SingleEqualsString;
                        }
                        else if (leftType == typeUsual || rightType == typeUsual)
                        {
                            opType = VOOperatorType.SingleEqualsUsual;
                        }
                        if (leftType == typePSZ || rightType == typePSZ)
                        {
                            opType = VOOperatorType.PSZCompare;
                        }
                        if (leftType == typeUsual || rightType == typeUsual)
                        {
                            if (leftType == typeSym || rightType == typeSym)
                            {
                                opType = VOOperatorType.SymbolCompare;
                            }
                        }
                        break;
                    case XSharpParser.EEQ:
                        if (leftType == typePSZ || rightType == typePSZ)
                        {
                            opType = VOOperatorType.PSZCompare;
                        }
                        if (leftType == typeUsual || rightType == typeUsual)
                        {
                            if (leftType == typeSym || rightType == typeSym)
                            {
                                opType = VOOperatorType.SymbolCompare;
                            }
                        }
                        break;
                    case XSharpParser.NEQ:
                    case XSharpParser.NEQ2:
                        if (leftType == typeUsual || rightType == typeUsual) // || right.Type?.SpecialType == SpecialType.System_String))
                        {
                            opType = VOOperatorType.NotEqualsUsual;
                        }
                        else if (leftType == typePSZ || rightType == typePSZ)
                        {
                            opType = VOOperatorType.PSZCompare;
                        }
                        break;
                    case XSharpParser.GT:
                    case XSharpParser.GTE:
                    case XSharpParser.LT:
                    case XSharpParser.LTE:
                        if (leftType == typeUsual || rightType == typeUsual)
                        {
                            // when LHS or RHS == USUAL then do not compare with CompareString
                            // but let the operator methods inside USUAL handle it.
                            opType = VOOperatorType.None;
                        }
                        else if (leftType?.SpecialType == SpecialType.System_String || rightType?.SpecialType == SpecialType.System_String)
                        {
                            if (leftType?.SpecialType != SpecialType.System_Char && rightType?.SpecialType != SpecialType.System_Char)
                            {
                                // Convert to String.Compare or __StringCompare. Decide later
                                opType = VOOperatorType.CompareString;
                            }
                        }
                        if (leftType == Compilation.GetSpecialType(SpecialType.System_Boolean) &&
                            rightType == Compilation.GetSpecialType(SpecialType.System_Boolean))
                        {
                            opType = VOOperatorType.LogicCompare;
                        }
                        break;
                    case XSharpParser.MINUS:
                    case XSharpParser.PLUS:
                        if (xnode.Op.Type == XSharpParser.MINUS)
                        {
                            // String Subtract 
                            // LHS    - RHS
                            // STRING - STRING 
                            // STRING -- USUAL
                            // USUAL  - STRING
                            if (leftType?.SpecialType == SpecialType.System_String)
                            {
                                if (rightType?.SpecialType == SpecialType.System_String || rightType == typeUsual)
                                {
                                    opType = VOOperatorType.SubtractString;
                                }
                            }
                            else if (leftType == typeUsual && rightType?.SpecialType == SpecialType.System_String)
                            {
                                opType = VOOperatorType.SubtractString;
                            }
                        }
                        if (opType == VOOperatorType.None)
                        { 
                            typeDate = Compilation.DateType();
                            typeFloat = Compilation.FloatType();

                            // Add or Subtract USUAL with other type
                            // LHS   - RHS 
                            // Usual - Date
                            // Date  - Usual
                            // Usual - Float
                            // Float - Usual
                            if (leftType == typeUsual)
                            { 
                                if (rightType == typeDate || rightType == typeFloat)
                                {
                                    opType = VOOperatorType.UsualOther;
                                }
                            }
                            if (rightType == typeUsual)
                            {
                                if (leftType == typeDate || leftType == typeFloat)
                                {
                                    opType = VOOperatorType.UsualOther;
                                }
                            }
                        }
                        break;
                    default:
                        switch (node.Kind())
                        {
                            case SyntaxKind.RightShiftExpression:
                            case SyntaxKind.LeftShiftExpression:
                            case SyntaxKind.RightShiftAssignmentExpression:
                            case SyntaxKind.LeftShiftAssignmentExpression:
                                opType = VOOperatorType.Shift;
                                break;
                            default:
                                opType = VOOperatorType.None;
                                break;
                        }
                        break;
                }
            }
            else
            {
                switch (node.Kind())
                {
                    case SyntaxKind.GreaterThanExpression:
                    case SyntaxKind.GreaterThanOrEqualExpression:
                    case SyntaxKind.LessThanExpression:
                    case SyntaxKind.LessThanOrEqualExpression:
                        if (leftType?.SpecialType == SpecialType.System_String || rightType?.SpecialType == SpecialType.System_String)
                        {
                            // Make to String.Compare or __StringCompare. Decide later
                            opType = VOOperatorType.CompareString;
                        }
                        break;
                    case SyntaxKind.RightShiftExpression:
                    case SyntaxKind.LeftShiftExpression:
                    case SyntaxKind.RightShiftAssignmentExpression:
                    case SyntaxKind.LeftShiftAssignmentExpression:
                        opType = VOOperatorType.Shift;
                        break;

                }

            }
            return opType;
        }
        private void AdjustVOUsualLogicOperands(BinaryExpressionSyntax node, ref BoundExpression left, ref BoundExpression right, DiagnosticBag diagnostics)
        {
            if (!Compilation.Options.IsDialectVO)
                return;
            XSharpParser.BinaryExpressionContext xnode = null;
            if (node.XNode is XSharpParser.BinaryExpressionContext)
            {
                xnode = node.XNode as XSharpParser.BinaryExpressionContext;
            }
            else if (node.XNode is XSharpParser.CodeblockCodeContext)
            {
                var cbc = node.XNode as XSharpParser.CodeblockCodeContext;
                if (cbc.Expr is XSharpParser.BinaryExpressionContext)
                    xnode = cbc.Expr as XSharpParser.BinaryExpressionContext;
            }
            if (xnode == null)  // this may happen for example for nodes generated in the transformation phase
                return;
            // check for Logic operations with Usual. If that is the case then add a conversion to the expression
            switch (xnode.Op.Type)
            {
                case XSharpParser.LOGIC_AND:
                case XSharpParser.LOGIC_OR:
                case XSharpParser.LOGIC_XOR:
                case XSharpParser.AND:
                case XSharpParser.OR:
                    var usualType = Compilation.UsualType();
                    var boolType = this.GetSpecialType(SpecialType.System_Boolean,diagnostics, node);
                    if (left.Type == usualType)
                    {
                        left = CreateConversion(left, boolType, diagnostics);
                    }

                    if (right.Type == usualType)
                    {
                        right = CreateConversion(right, boolType, diagnostics);
                    }
                    break;
            }
            return;
        }
        public BoundExpression RewriteIndexAccess(BoundExpression index, DiagnosticBag diagnostics)
        {
            if (!index.HasAnyErrors && !this.Compilation.Options.ArrayZero)
            {
                var kind = BinaryOperatorKind.Subtraction;
                var left = index;
                var right = new BoundLiteral(index.Syntax, ConstantValue.Create(1), index.Type) { WasCompilerGenerated = true };
                int compoundStringLength = 0;
                var leftType = left.Type;
                var opKind = leftType.SpecialType == SpecialType.System_Int32 ? BinaryOperatorKind.IntSubtraction
                    : leftType.SpecialType == SpecialType.System_Int64 ? BinaryOperatorKind.LongSubtraction
                    : leftType.SpecialType == SpecialType.System_UInt32 ? BinaryOperatorKind.UIntSubtraction
                    : BinaryOperatorKind.ULongSubtraction;
                var resultConstant = FoldBinaryOperator((CSharpSyntaxNode)index.Syntax, opKind, left, right, left.Type.SpecialType, diagnostics, ref compoundStringLength);
                var sig = this.Compilation.builtInOperators.GetSignature(opKind);
                index = new BoundBinaryOperator(index.Syntax, kind, left, right, resultConstant, sig.Method,
                    resultKind: LookupResultKind.Viable,
                    originalUserDefinedOperatorsOpt: ImmutableArray<MethodSymbol>.Empty,
                    type: index.Type,
                    hasErrors: false)
                { WasCompilerGenerated = true };
            }
            return index;
        }
        public TypeSymbol VOGetType(BoundExpression expr)
        {
            if (expr.Kind == BoundKind.Literal)
            {
                var lit = expr as BoundLiteral;
                if (lit.ConstantValue.Discriminator == ConstantValueTypeDiscriminator.Int32)
                {
                    var val = lit.ConstantValue.Int32Value;
                    if (val >= Byte.MinValue && val <= Byte.MaxValue)
                        return Compilation.GetSpecialType(SpecialType.System_Byte);
                    else if (val >= Int16.MinValue && val <= Int16.MaxValue)
                        return Compilation.GetSpecialType(SpecialType.System_Int16);
                }
            }
            else if (expr.Kind ==BoundKind.UnaryOperator)
            {
                var unary = expr as BoundUnaryOperator;
                var type = VOGetType(unary.Operand);
                if (unary.OperatorKind.Operator() == UnaryOperatorKind.IntUnaryMinus)
                {
                    // see if we must change unsigned into signed
                    if (type == Compilation.GetSpecialType(SpecialType.System_Byte))
                    {
                        type = Compilation.GetSpecialType(SpecialType.System_Int16);
                    }
                    else if (type == Compilation.GetSpecialType(SpecialType.System_UInt16))
                    {
                        type = Compilation.GetSpecialType(SpecialType.System_Int32);
                    }
                    else if (type == Compilation.GetSpecialType(SpecialType.System_UInt32))
                    {
                        type = Compilation.GetSpecialType(SpecialType.System_Int64);
                    }
                }
                return type;
            }
            return expr.Type;
        }
        public void VODetermineIIFTypes(ConditionalExpressionSyntax node, DiagnosticBag diagnostics,
            ref BoundExpression trueExpr, ref BoundExpression falseExpr, 
            ref TypeSymbol trueType, ref TypeSymbol falseType)
        {
            // do nothing when the types null
            if (trueType != null && falseType != null)
            {
                // Determine underlying types. For literal numbers this may be Byte, Short, Int or Long
                trueType = VOGetType(trueExpr);
                falseType = VOGetType(falseExpr);
                if (trueType != falseType && trueType.IsIntegralType() && falseType.IsIntegralType())
                {
                    // Determine the largest of the two integral types and scale up
                    if (trueType.SpecialType.SizeInBytes() > falseType.SpecialType.SizeInBytes())
                        falseType = trueType;
                    else
                        trueType = falseType;
                }

                if (trueType != falseType && Compilation.Options.IsDialectVO)
                {
                    // convert to usual when one of the two is a usual
                    var usualType = Compilation.UsualType();
                    if (trueType == usualType)
                    {
                        falseType = trueType;
                        falseExpr = CreateConversion(falseExpr, usualType, diagnostics);
                    }
                    else if (falseType == usualType)
                    {
                        trueType = falseType;
                        trueExpr = CreateConversion(trueExpr, usualType, diagnostics);
                    }
                    else if (Compilation.Options.VOCompatibleIIF)
                    {
                        // convert to usual when Compatible IIF is activated
                        trueExpr = CreateConversion(trueExpr, usualType, diagnostics);
                        falseExpr = CreateConversion(falseExpr, usualType, diagnostics);
                        trueType = falseType = usualType;
                    }
                }
                if (trueType != falseType )
                {
                    if (trueType.IsVoidPointer())
                    {
                        if (falseType == Compilation.GetSpecialType(SpecialType.System_IntPtr))
                        {
                            trueExpr = CreateConversion(trueExpr, falseType, diagnostics);
                            trueType = falseType;
                        }
                    }
                    else if (falseType.IsVoidPointer())
                    {
                        if (trueType == Compilation.GetSpecialType(SpecialType.System_IntPtr))
                        {
                            falseExpr = CreateConversion(falseExpr, trueType, diagnostics);
                            falseType = trueType;
                        }
                    }
                    else if (Compilation.Options.VOCompatibleIIF)
                    {
                        // convert to object when Compatible IIF is activated
                        // this will not happen for VO Dialect because that is handled above
                        var objectType = Compilation.GetSpecialType(SpecialType.System_Object);
                        trueExpr = CreateConversion(trueExpr, objectType, diagnostics);
                        falseExpr = CreateConversion(falseExpr, objectType, diagnostics);
                        trueType = falseType = objectType;
                    }

                }
            }
        }
    }
}
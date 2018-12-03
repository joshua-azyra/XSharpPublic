﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Reflection.Emit;

namespace XSharp.MacroCompiler.Syntax
{
    using static CodeGen;

    internal partial class Node
    {
        internal virtual void Emit(ILGenerator ilg) { throw new NotImplementedException(); }
    }
    internal partial class Expr : Node
    {
        internal virtual void Emit(ILGenerator ilg, bool preserve) { }
        internal virtual void EmitSet(ILGenerator ilg, bool preserve) { throw new NotImplementedException(); }
        internal virtual void EmitAddr(ILGenerator ilg) { throw new NotImplementedException(); }
        internal sealed override void Emit(ILGenerator ilg) { Emit(ilg, true); }
    }
    internal partial class StoreTemp : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg);
            if (preserve)
                ilg.Emit(OpCodes.Dup);
            Local.Declare(ilg);
            Local.EmitSet(ilg);
        }
        internal override void EmitSet(ILGenerator ilg, bool preserve)
        {
            Expr.EmitSet(ilg, preserve);
        }
    }
    internal partial class LoadTemp : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr?.Emit(ilg, false);
            if (preserve)
                Temp.Local.EmitGet(ilg);
        }
    }
    internal partial class TypeExpr : Expr
    {
    }
    internal partial class NativeTypeExpr : TypeExpr
    {
    }
    internal partial class NameExpr : TypeExpr
    {
    }
    internal partial class IdExpr : NameExpr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (preserve)
                Symbol.EmitGet(ilg);
        }
        internal override void EmitSet(ILGenerator ilg, bool preserve)
        {
            if (preserve)
                ilg.Emit(OpCodes.Dup);
            Symbol.EmitSet(ilg);
        }
        internal override void EmitAddr(ILGenerator ilg)
        {
            Symbol.EmitAddr(ilg);
        }
    }
    internal partial class MemberAccessExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg);
            Symbol.EmitGet(ilg);
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
        internal override void EmitSet(ILGenerator ilg, bool preserve)
        {
            if (preserve)
                ilg.Emit(OpCodes.Dup);
            Expr.Emit(ilg);
            Symbol.EmitSet(ilg);
        }
    }
    internal partial class QualifiedNameExpr : NameExpr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Symbol.EmitGet(ilg);
        }
        internal override void EmitSet(ILGenerator ilg, bool preserve)
        {
            if (preserve)
                ilg.Emit(OpCodes.Dup);
            Symbol.EmitSet(ilg);
        }
    }
    internal partial class AssignExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Right.Emit(ilg);
            Left.EmitSet(ilg, preserve);
        }
    }
    internal partial class AssignOpExpr : AssignExpr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Right.Emit(ilg);
            Left.EmitSet(ilg, preserve);
        }
    }
    internal partial class BinaryExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (Symbol is BinaryOperatorSymbol)
            {
                Left.Emit(ilg);
                Right.Emit(ilg);
                (Symbol as BinaryOperatorSymbol).Emit(this, Datatype, ilg);
            }
            else
                throw new NotImplementedException();
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class BinaryLogicExpr : BinaryExpr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (Symbol is BinaryOperatorSymbol)
            {
                var lb = ilg.DefineLabel();
                var op = (Symbol as BinaryOperatorSymbol);
                Left.Emit(ilg);
                ilg.Emit(OpCodes.Dup);
                switch (op.Kind)
                {
                    case BinaryOperatorKind.And:
                        ilg.Emit(OpCodes.Brfalse_S, lb);
                        break;
                    case BinaryOperatorKind.Or:
                        ilg.Emit(OpCodes.Brtrue_S, lb);
                        break;
                    default:
                        throw new NotImplementedException();
                }
                ilg.Emit(OpCodes.Pop);
                Right.Emit(ilg);
                ilg.MarkLabel(lb);
            }
            else
                throw new NotImplementedException();
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class UnaryExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg);
            if (Symbol is UnaryOperatorSymbolWithMethod)
            {
                var op = (UnaryOperatorSymbolWithMethod)Symbol;
                ilg.Emit(OpCodes.Call, op.Method.Method);
            }
            else if (Symbol is UnaryOperatorSymbol)
            {
                var op = (UnaryOperatorSymbol)Symbol;
                EmitUnaryOperator(ilg, op, Datatype); // TODO nkok: handle checked/unchecked
            }
            else
            {
                throw new NotImplementedException();
            }
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class PrefixExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg);
            Left.EmitSet(ilg, preserve);
        }
    }
    internal partial class PostfixExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg);
            Left.EmitSet(ilg, false);
            Temp.Emit(ilg);
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class LiteralExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (preserve)
            {
                ((Constant)Symbol).Emit(ilg);
            }
        }
    }
    internal partial class SelfExpr : Expr
    {
        // Not supported
    }
    internal partial class SuperExpr : Expr
    {
        // Not supported
    }
    internal partial class CheckedExpr : Expr
    {
        // TODO (nvk): to be implemented
    }
    internal partial class UncheckedExpr : Expr
    {
        // TODO (nvk): to be implemented
    }
    internal partial class TypeOfExpr : Expr
    {
        // TODO (nvk): to be implemented
    }
    internal partial class SizeOfExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (preserve)
            {
                ilg.Emit(OpCodes.Sizeof, (Symbol as TypedSymbol).Type.Type);
            }
        }
    }
    internal partial class DefaultExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            EmitDefault(ilg, (TypeSymbol)Symbol);
        }
    }
    internal partial class TypeCast : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            ((ConversionSymbol)Symbol).Emit(Expr, Datatype, ilg);
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class TypeConversion : TypeCast
    {
    }
    internal partial class IsExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg, preserve);
            if (preserve)
            {
                ilg.Emit(OpCodes.Isinst, (Symbol as TypedSymbol).Type.Type);
                ilg.Emit(OpCodes.Ldnull);
                ilg.Emit(OpCodes.Cgt_Un);
            }
        }
    }
    internal partial class AsTypeExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Expr.Emit(ilg, preserve);
            if (preserve)
            {
                ilg.Emit(OpCodes.Isinst, Datatype.Type);
            }
        }
    }
    internal partial class MethodCallExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (Self != null) Self.Emit(ilg);
            Args.Emit(ilg);
            var m = (MethodSymbol)Symbol;
            ilg.Emit(Self == null ? OpCodes.Call : OpCodes.Callvirt, m.Method);
            if (!preserve && Datatype.NativeType != NativeType.Void)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class CtorCallExpr : MethodCallExpr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (Datatype.Type.IsValueType && Args.Args.Count == 0)
            {
                var l = ilg.DeclareLocal(Datatype.Type);
                ilg.Emit(l.LocalIndex < 256 ? OpCodes.Ldloca_S : OpCodes.Ldloca, l);
                ilg.Emit(OpCodes.Initobj, Datatype.Type);
                if (preserve)
                    ilg.Emit(l.LocalIndex < 256 ? OpCodes.Ldloc_S : OpCodes.Ldloc, l);
            }
            else
            {
                Args.Emit(ilg);
                var c = (ConstructorSymbol)Symbol;
                ilg.Emit(OpCodes.Newobj, c.Constructor);
                if (!preserve)
                    ilg.Emit(OpCodes.Pop);
            }
        }
    }
    internal partial class ArrayAccessExpr : MethodCallExpr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (Self != null) Self.Emit(ilg);
            Args.Emit(ilg);
            var m = (PropertySymbol)Symbol;
            ilg.Emit(Self == null ? OpCodes.Call : OpCodes.Callvirt, m.Getter.Method);
            if (!preserve && Datatype.NativeType != NativeType.Void)
                ilg.Emit(OpCodes.Pop);
        }
        internal override void EmitSet(ILGenerator ilg, bool preserve)
        {
            if (preserve)
                ilg.Emit(OpCodes.Dup);
            var t = ilg.DeclareLocal(Datatype.Type);
            ilg.Emit(OpCodes.Stloc, t.LocalIndex);
            if (Self != null) Self.Emit(ilg);
            Args.Emit(ilg);
            ilg.Emit(OpCodes.Ldloc, t.LocalIndex);
            var m = (PropertySymbol)Symbol;
            ilg.Emit(Self == null ? OpCodes.Call : OpCodes.Callvirt, m.Setter.Method);
        }
    }
    internal partial class EmptyExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            if (preserve)
                ((Constant)Symbol).Emit(ilg);
        }
    }
    internal partial class Arg : Node
    {
        internal override void Emit(ILGenerator ilg)
        {
            Expr.Emit(ilg, true);
        }
    }
    internal partial class ExprList : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            for (int i = 0; i < Exprs.Count-1; i++)
            {
                Exprs[i].Emit(ilg, false);
            }
            Exprs.LastOrDefault()?.Emit(ilg, preserve);
        }
    }
    internal partial class LiteralArray : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            EmitConstant_I4(ilg, Values.Exprs.Count);
            ilg.Emit(OpCodes.Newarr, (Symbol as TypeSymbol).Type);
            for (int i = 0; i < Values.Exprs.Count; i++)
            {
                ilg.Emit(OpCodes.Dup);
                EmitConstant_I4(ilg, i);
                Values.Exprs[i].Emit(ilg);
                EmitArrayStoreElem(ilg, Symbol as TypeSymbol);
            }
            if (Datatype.NativeType == NativeType.Array)
            {
                ilg.Emit(OpCodes.Newobj, (Compilation.Get(WellKnownMembers.XSharp___Array_ctor) as ConstructorSymbol).Constructor);
            }
            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class IifExpr : Expr
    {
        internal override void Emit(ILGenerator ilg, bool preserve)
        {
            Cond.Emit(ilg);
            var lbFalse = ilg.DefineLabel();
            var lbTrue = ilg.DefineLabel();
            ilg.Emit(OpCodes.Brfalse_S, lbFalse);
            True.Emit(ilg);
            ilg.Emit(OpCodes.Br, lbTrue);
            ilg.MarkLabel(lbFalse);
            False.Emit(ilg);
            ilg.MarkLabel(lbTrue);

            if (!preserve)
                ilg.Emit(OpCodes.Pop);
        }
    }
    internal partial class ArgList : Node
    {
        internal override void Emit(ILGenerator ilg)
        {
            foreach (var a in Args)
            {
                a.Emit(ilg);
            }
        }
    }
    internal partial class Codeblock : Node
    {
        internal override void Emit(ILGenerator ilg)
        {
            if (Params != null)
            {
                foreach (var p in Params)
                {
                    LocalSymbol ls = (LocalSymbol)p.Symbol;
                    ls.Declare(ilg);

                    var idx = Constant.Create(ls.Index);
                    var skip = ilg.DefineLabel();
                    var lidx = Constant.Create(ls.Index);

                    ParamArray.EmitGet(ilg);
                    ilg.Emit(OpCodes.Ldlen);
                    ilg.Emit(OpCodes.Conv_I4);
                    lidx.Emit(ilg);
                    ilg.Emit(OpCodes.Cgt);
                    ilg.Emit(OpCodes.Brfalse_S, skip);

                    ParamArray.EmitGet(ilg);
                    lidx.Emit(ilg);
                    ilg.Emit(OpCodes.Ldelem_Ref);
                    ls.EmitSet(ilg);

                    ilg.MarkLabel(skip);
                }
            }
            bool isVoid = true;
            if (Body != null)
            {
                isVoid &= Body.Datatype.NativeType == NativeType.Void;
                Body.Emit(ilg,true);
            }
            if (isVoid)
            {
                EmitDefault(ilg,(TypeSymbol)Symbol);
            }
            ilg.Emit(OpCodes.Ret);
        }
    }
}

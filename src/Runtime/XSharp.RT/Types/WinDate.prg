﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
USING System.Collections
USING System.Collections.Generic
USING System.Linq
USING System.Diagnostics
USING System.Runtime.Serialization
USING System.Runtime.CompilerServices

#include "attributes.xh"
BEGIN NAMESPACE XSharp
/// <summary>Internal type that implements the XBase Compatible DATE type in UNIONs and VOSTRUCTs</summary>
[DebuggerDisplay("WinDate({ToString(),nq})", Type := "DATE")];
[Serializable];
PUBLIC STRUCT __WinDate IMPLEMENTS ISerializable
    PRIVATE INITONLY _value AS DWORD			// Julian value
    /// <summary>Value as Date</summary>
    PUBLIC PROPERTY @@Value AS DATE => (DATE) _value
    /// <summary>Value as Julian Number, 0 for NULL_DATE</summary>
    PUBLIC PROPERTY @@JulianValue AS INT => (INT) _value

    PRIVATE CONSTRUCTOR(@@value AS DWORD)
        _value := @@value

    /// <summary>This constructor is used in code generated by the compiler when needed.</summary>
    CONSTRUCTOR (dValue AS DATE)
        _value := (DWORD) dValue

    /// <inheritdoc />
    OVERRIDE METHOD GetHashCode() AS INT
        RETURN _value:GetHashCode()

    /// <exclude />
    METHOD GetTypeCode() AS TypeCode
        RETURN TypeCode.DateTime

    /// <inheritdoc />
    OVERRIDE METHOD ToString() AS STRING
        RETURN @@Value:ToString()


#region Unary Operators
#endregion

#region Binary Operators
    /// <exclude />
    [NODEBUG]  [INLINE];
    OPERATOR == (lhs AS __WinDate, rhs AS __WinDate) AS LOGIC
        RETURN lhs:_value == rhs:_value

    /// <exclude />
    [NODEBUG]  [INLINE];
    OPERATOR != (lhs AS __WinDate, rhs AS __WinDate) AS LOGIC
        RETURN lhs:_value != rhs:_value

    /// <exclude />
    [NODEBUG]  [INLINE];
    OPERATOR == (lhs AS __WinDate, rhs AS DATE) AS LOGIC
        RETURN lhs:@@Value == rhs

    /// <exclude />
    [NODEBUG]  [INLINE];
    OPERATOR != (lhs AS __WinDate, rhs AS DATE) AS LOGIC
        RETURN lhs:@@Value != rhs

    /// <exclude />
    [NODEBUG]  [INLINE];
    OPERATOR == (lhs AS DATE, rhs AS __WinDate) AS LOGIC
        RETURN lhs == rhs:@@Value

    /// <exclude />
    [NODEBUG]  [INLINE];
    OPERATOR != (lhs AS DATE, rhs AS __WinDate) AS LOGIC
        RETURN lhs != rhs:@@Value

    /// <inheritdoc />
    PUBLIC OVERRIDE METHOD Equals(obj AS OBJECT) AS LOGIC
        IF obj IS __WinDate
            RETURN SELF:_value == ((__WinDate) obj):_value
        ENDIF
        RETURN FALSE
#endregion

#region Implicit Converters
    /// <exclude />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR IMPLICIT(wd AS __WinDate) AS DATE
        RETURN wd:@@Value

    /// <exclude />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR IMPLICIT(u AS USUAL) AS __WinDate
        RETURN __WinDate{(DATE) u}

    /// <exclude />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR IMPLICIT(d AS DATE) AS __WinDate
        RETURN __WinDate{d}

    /// <exclude />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR IMPLICIT(wd AS __WinDate) AS USUAL
        RETURN wd:@@Value


    /// <exclude />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR IMPLICIT(wd AS __WinDate) AS LONG
        RETURN wd:@@JulianValue

    [NODEBUG]  [INLINE];
    STATIC OPERATOR IMPLICIT(wd AS __WinDate) AS DWORD
        RETURN (DWORD) (Date) wd


#endregion

#region Binary Operators
        // These are all delegated to the equivalent methods inside the Date
    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR ++(lhs AS __WinDate) AS __WinDate
        RETURN lhs:Value:Add(1)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, days AS USUAL) AS __WinDate
        RETURN lhs:Value:Add(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, days AS REAL8) AS __WinDate
        RETURN lhs:Value:Add(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, days AS LONG) AS __WinDate
        RETURN lhs:Value:Add(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, days AS INT64) AS __WinDate
        RETURN lhs:Value:Add(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, ts AS System.TimeSpan) AS __WinDate
        RETURN lhs:Value:Add(ts)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, days AS DWORD) AS __WinDate
        RETURN lhs:Value:Add(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR +(lhs AS __WinDate, days AS UINT64) AS __WinDate
        RETURN lhs:Value:Add(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR --(lhs AS __WinDate) AS __WinDate
        RETURN lhs:Value:Subtract(1)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, rhs AS __WinDate) AS LONG
        RETURN lhs:Value:Subtract(rhs:Value)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, days AS USUAL) AS USUAL
        RETURN lhs:Value:Subtract(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, days AS REAL8) AS __WinDate
        RETURN lhs:Value:Subtract(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, days AS LONG) AS __WinDate
        RETURN lhs:Value:Subtract(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, days AS INT64) AS __WinDate
        RETURN lhs:Value:Subtract(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, ts AS System.TimeSpan) AS __WinDate
        RETURN lhs:Value:Subtract(ts)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, days AS DWORD) AS __WinDate
        RETURN lhs:Value:Subtract(days)

    /// <include file="RTComments.xml" path="Comments/Operator/*" />
    [NODEBUG]  [INLINE];
    STATIC OPERATOR -(lhs AS __WinDate, days AS UINT64) AS __WinDate
        RETURN lhs:Value:Subtract(days)
#endregion

#region ISerializable
    /// <inheritdoc/>
    PUBLIC METHOD GetObjectData(info AS SerializationInfo, context AS StreamingContext) AS VOID
        IF info == NULL
            THROW System.ArgumentException{"info"}
        ENDIF
        info:AddValue("Value", _value)
        RETURN

    /// <include file="RTComments.xml" path="Comments/SerializeConstructor/*" />
    CONSTRUCTOR (info AS SerializationInfo, context AS StreamingContext)
        IF info == NULL
            THROW System.ArgumentException{"info"}
        ENDIF
        _value := info:GetUInt32("Value")
#endregion

END	STRUCT
END NAMESPACE
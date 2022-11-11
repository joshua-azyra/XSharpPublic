﻿USING System.Text
USING XSharpModel
FUNCTION XSharpBuiltInFunctions(location as string) as STRING
    local sb as StringBuilder
    local asm as System.Reflection.Assembly
    asm := System.Reflection.Assembly.GetAssembly(TypeOf(XAssembly))
    sb := StringBuilder{1024}
    sb:AppendLine("//")
    sb:AppendLine("// Comments: This file contains the prototypes of the pseudo functions that are built into the compiler")
    sb:AppendLine("// Location: "+location)
    sb:AppendLine("// Version :  "+ asm:GetName():ToString())
    sb:AppendLine("")
    var sLine1 := "/// <summary>Inline Conditional Expression</summary>"
    var sLine2 := e"/// <param name=\"cond\">The condition. This should evaluate to TRUE or FALSE.</param>"
    var sLine3 := e"/// <param name=\"trueExpr\">The expression to return when the condition evaluates to TRUE.</param>"
    var sLine4 := e"/// <param name=\"falseExpr\">The expression to return when the condition evaluates to FALSE.</param>"
    var sLine5 := "FUNCTION {0}(cond AS LOGIC, trueExpr as USUAL, falseExpr as USUAL) AS USUAL"
    sb:AppendLine(sLine1)
    sb:AppendLine(sLine2)
    sb:AppendLine(sLine3)
    sb:AppendLine(sLine4)
    sb:AppendLine(String.Format(sLine5, "IIF"))
    sb:AppendLine("")
    sb:AppendLine(sLine1)
    sb:AppendLine(sLine2)
    sb:AppendLine(sLine3)
    sb:AppendLine(sLine4)
    sb:AppendLine(String.Format(sLine5, "IF"))
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Return the name of an identifier as a string</summary>")
    sb:AppendLine(e"/// <param name=\"expr\">An Identifier. This could be the name of a variable or type.</param>")
    sb:AppendLine("FUNCTION NameOf(expr AS OBJECT) AS STRING")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Convert an ASCII code to a character value. </summary>")
    sb:AppendLine("/// <remarks>Values between 1 and 127 are stored as literal by the compiler. Larger values are handled at runtime because they depend on the current codepage </remarks>")
    sb:AppendLine(e"/// <param name=\"dwCode\">An ASCII code from 0 to 255.</param>")
    sb:AppendLine("FUNCTION Chr(dwCode as DWORD) AS STRING")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Convert an ASCII code to a character value. </summary>")
    sb:AppendLine("/// <remarks>Values between 1 and 127 are stored as literal by the compiler. Larger values are handled at runtime because they depend on the current codepage </remarks>")
    sb:AppendLine(e"/// <param name=\"dwCode\">An ASCII code from 0 to 255.</param>")
    sb:AppendLine("FUNCTION _Chr(dwCode as DWORD) AS STRING")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Return the type of an expression as a System.Type.</summary>")
    sb:AppendLine(e"/// <param name=\"expr\">The expression to check.</param>")
    sb:AppendLine("FUNCTION TypeOf(expr as OBJECT) AS System.Type")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Return the size of an expression</summary>")
    sb:AppendLine(e"/// <param name=\"expr\">The expression to check. Must be a type or a variable.</param>")
    sb:AppendLine("FUNCTION SizeOf(expr as OBJECT) AS LONG")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Return the number of parameters that were passed to a function/method of the Clipper calling convention.</summary>")
    sb:AppendLine("FUNCTION PCount() AS DWORD")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Return the number of arguments that were declared for a function/method of the Clipper calling convention.</summary>")
    sb:AppendLine("FUNCTION ArgCount() AS DWORD")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Return the parameters that were passed to a function/method of the Clipper calling convention as an array of Usuals</summary>")
    sb:AppendLine("FUNCTION _Args() AS USUAL[]")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Retrieve a parameter in a function/method of the Clipper calling convention by position.</summary>")
    sb:AppendLine(e"/// <param name=\"nParam\">A Number between 1 and PCount()</param>")
    sb:AppendLine("FUNCTION _GetMParam(nParam as DWORD) AS USUAL")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Retrieve a parameter in a function/method of the Clipper calling convention by position.</summary>")
    sb:AppendLine(e"/// <param name=\"nParam\">A Number between 1 and PCount()</param>")
    sb:AppendLine("FUNCTION _GetFParam(nParam as DWORD) AS USUAL")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>This function will return the module handle for the current module.</summary>")
    sb:AppendLine("FUNCTION _GetInst() AS PTR")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Convert a string to PSZ.</summary>")
    sb:AppendLine("/// <remarks>Please note that the PSZ is automatically released when the current function/method ends. <br/>")
    sb:AppendLine("/// Use StringAlloc() to allocate PSZ values that are not automatically freed.</remarks>")
    sb:AppendLine(e"/// <param name=\"s\">The string to convert</param>")
    sb:AppendLine("FUNCTION String2Psz(s as STRING) AS PSZ")
    sb:AppendLine("")
    sb:AppendLine("/// <summary>Convert a string to PSZ. Please note that the PSZ is automatically released when the current function/method ends.</summary>")
    sb:AppendLine("/// <remarks>Please note that the PSZ is automatically released when the current function/method ends. <br/>")
    sb:AppendLine("/// Use StringAlloc() to allocate PSZ values that are not automatically freed.</remarks>")
    sb:AppendLine(e"/// <param name=\"s\">The string to convert</param>")
    sb:AppendLine("FUNCTION Cast2Psz(s as STRING) AS PSZ")
    sb:AppendLine("")
    return sb:ToString()


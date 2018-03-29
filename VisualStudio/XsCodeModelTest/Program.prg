﻿USING System
USING System.Collections.Generic
USING System.Linq
USING System.Text
Using XSharpModel
BEGIN NAMESPACE XsCodeModelTest


function Start() as void
local cFileName as string
	cFileName := "C:\Test\test.prg"
	cFileName := "C:\VIDE\Projects\XIDE\VIDE\PIDE.prg"
	cFileName := "c:\temp\InventoryRepILst.prg"
	ParseAndDisplay(System.IO.File.ReadAllLines(cFileName))
	Console.ReadLine()
return	


		function ParseAndDisplay(aLineCollection as IEnumerable<String>) as void
		local nLineCount as int
		local d as DateTime
		
		? "Starting parsing..."
		d := DateTime.Now
		//LineObject.LinesWithSpecialStuff:Clear()
		var parser := Parser{}
		nLineCount   := parser:Parse(aLineCollection)
		? "Parsing completed!"
		?
		? "Time elapsed:" , DateTime.Now - d
		?
		? "Total Lines:" , nLineCount
		//? "Entities:" , Parser:Entities:Count
		? "Types:" , Parser:Types:Count
		//? "Directives, block commands etc:" , LineObject.LinesWithSpecialStuff:Count
		?
		? "Press enter to list info"
		Console.ReadLine()
		?
		? "Types:"
		foreach oEntity as EntityObject in Parser:Types
			? "Line:" , oEntity:nLine ,"Type:" , oEntity:eType , "Name:" , oEntity:cName ,  "Children", oEntity:aChildren:Count
			? "Children:"
			foreach oChild as EntityObject in oEntity:aChildren
				? "  line:" , oChild:nLine , "Type:" , oChild:eType, "Name:" , oChild:cName ,  "Return Type =", oChild:cRetType
				if oChild:aChildren:Count > 0
					?? "  Locals: ", oChild:aChildren:Count
				endif
				foreach oLocal as EntityObject in oChild:aChildren
					? "      Line:" , oLocal:nLine , "Type:" , oLocal:eType , "Name:" , oLocal:cName ,  "Return Type =", oLocal:cRetType
				next
				if oChild:aParams != null
					? "  Parameters: ", oChild:aParams:Count
					foreach oParam as EntityParamsObject in oChild:aParams
						? "      Parameter:" , oParam:cName, oParam:cType, oParam:lReference
					next
				endif
			next
			Console.ReadLine()
		next
		//Console.ReadLine()

		//? "Entities:"
		//foreach oEntity as EntityObject in Parser:Entities
		//? "Line:" , oEntity:nLine , "Name:" , oEntity:cName , "Type:" , oEntity:eType , "Return Type =", oEntity:cRetType
		//next
		//Console.ReadLine()
		//? "Locals:"
		//foreach oLocal as EntityObject in Parser:Locals
		//? "Line:" , oLocal:nLine , "Name:" , oLocal:cName , "Type =", oLocal:cRetType
		//next
//
		//Console.ReadLine()
		/*
		?
		? "Directives, Block commands etc:"
		foreach oLine as LineObject in Parser:LineObjects
			if oLine:eType == LineType.EndClass .or. oLine:eType == LineType.Return .or. oLine:eType == LineType.Define
				//loop
			end if
			? "Line:" , oLine:Line , "OffSet:", oLine:OffSet,  "Type:" , oLine:eType , ":" , oLine:cArgument
		next
		*/
		
		return	
END NAMESPACE

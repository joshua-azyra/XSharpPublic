﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LanguageService.CodeAnalysis.XSharp;
using LanguageService.CodeAnalysis.XSharp.Syntax;

// The antlr4 runtime is contained in these namespaces
using LanguageService.SyntaxTree;
using LanguageService.SyntaxTree.Atn;
using LanguageService.SyntaxTree.Misc;
using LanguageService.SyntaxTree.Tree;
using LanguageService.CodeAnalysis.XSharp.SyntaxParser;


namespace ParserTester
{
	class Program
	{
		static void Main(string[] args)
		{
			//var rdr = new System.IO.StreamReader(@"d:\Vewa6\DevU\SDK\VOSDK\RDD_Classes_SDK\DbServer.prg");
			//var source = rdr.ReadToEnd();
			string[] noerrors = new string[]{""
            , "Function Foo()\nConsole.WriteLine(e\"\\r\\nThe quick brown fox\t\")\n"
			, "Function Foo()\nConsole.WriteLine(e\"\\xABCD\")\n"
			, "Function Foo()\nConsole.WriteLine(e\"\\u0066\")\n"
			, "Function Foo()\nConsole.WriteLine(e\"\\a\\b\\f\\n\\r\\t\\v\")\n"
			, "Function Main()\nRETURN 1\nPROCEDURE Foo()\nRETURN\n"
			,"CLASS Foo \nEXPORT Foo:= '123', Bar AS STRING\nEND CLASS\n"					// 
			, "#using System\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x\n"
			, "#pragma options(\"az\",on)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x\n#pragma options (\"az\",default)\n"
			//, "#pragma options(1,on)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x\n#pragma options (1,default)\n" // failure
			, "#pragma warnings(1,on)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x\n#pragma warnings (1,default)\n" // 
			//, "#pragma warnings(\"az\",on)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x\n#pragma warnings (\"az\",default)\n"		// Failure
			, "Function Main()\nLOCAL x := 'foo' as STRING\n x := 'aaa'\nRETURN x\n"
			, "Function Main()\nVAR x := 'foo' \n RETURN x\n"
			, "Function Main()\nIMPLIED x := 'foo'\n  RETURN x\n"
			, "Function Main()\nLOCAL IMPLIED x := 'foo' \n RETURN x\n"
			, "Function Main()\nSTATIC LOCAL x := 'foo' \n RETURN x\n"
			, "Function Main()\nLOCA x := 'foo' \n RETU x\n"
			, "Class Foo \n METHOD Bar()\nRETURN 10\nPROPERTY FooBar as STRING GET 'abc'\n END CLASS\n"
			, "Class Foo \n METHOD Bar()\nRETURN 10\nPROPERTY FooBar as STRING AUTO := 'abc' \n END CLASS\n"
			, "begin namespace Test\nClass Foo \n METHOD Bar()\nRETURN 10\nPROPERTY FooBar as STRING AUTO := 'abc' \n END CLASS \nEND NAMESPACE\n"
			, "procedure main\nLocal i as Long\nfor i := 1 to 10\n? i\nNext\nreturn\n"
			, "function Foo(bars as ICollection) AS LOGIC\nFOREACH IMPLIED bar in bars\n if bar IS Foo\nRETURN TRUE\nendif\nNEXT\nRETURN False\n" 
			//, "function Foo(bars as ICollection) AS LOGIC\nFOREACH IMPLIED bar in bars\n if bar IS Foo\nRETURN TRUE\nNEXT\nRETURN False\n" // missing Endif
			//, "function Foo(bars as ICollection) AS LOGIC\nFOREACH IMPLIED bar in bars\n if bar IS Foo\nRETURN TRUE\nendif\nRETURN False\n" // missing NEXT
			, "function Foo\nLOCAL x as LONGINT\nx := Sqrt(10)\nRETURN x\n"
			, "function Foo\nLOCAL x as LONGINT\nx := checked (Sqrt(10)) \nRETURN x\n"
			, "function Foo\nLOCAL x AS NAMESPACE,y,z \nx := unchecked (Sqrt(10))\nRETURN x\n"
			, "Class @@Class.Foo \n METHOD Bar()\nRETURN 10\nPROPERTY FooBar as STRING AUTO := 'abc' \n END CLASS\n"
			, "function Foo\nPRIVATE x,y,z\nx := Sqrt(10)\nRETURN x\n"
			, "function Foo\nPUBLIC x,y,z\nx := Sqrt(10)\nRETURN x\n"
			, "function Foo()\nPUBL x,y,z\nx := Sqrt(10)\nRETURN x\n"
			, "UNION Foo \n MEMBER Bar as LONG\nMEMBER FooBar as DATE\n"
			, "VOSTRUCT Foo ALIGN 8\n MEMBER Bar as LONG\nMEMBER FooBar as DATE\n"
			, "GLOBAL Foo,FooBar as BAR\n"
			, "GLOBAL DIM Foo[10] as Int\n"
			, "GLOBAL Foo := {} AS ARRAY\n"
			, "GLOBAL Foo[0] AS ARRAY\n"
			, "STATIC GLOBAL Foo AS STRING\n"
			, "INTERNAL GLOBAL Foo := '123' AS STRING"
			, "_DLL FUNCTION MessageBox(hwnd AS PTR, lpText AS PSZ, lpCaption AS PSZ, uType AS DWORD) AS INT PASCAL:USER32.'MessageBoxA'"
			,"CLASS Foo\n CLASS BAR\n END CLASS \nEND CLASS\n"			// Nested class
			,"CLASS Foo <T> WHERE T IS Customer, New() \n END CLASS\n"					// Generic Class
			,"CLASS Foo <T> WHERE T IS Class  \n END CLASS\n"					// Generic Class
			,"CLASS Foo <T> WHERE T IS Structure  \n END CLASS\n"					// Generic Class
			,"CLASS Foo <T> WHERE T IS @@UNION  \n END CLASS\n"					// Generic Class
			};
			//
			// These are strings that are supposed to fail !
			// Some of them are unsuported stuff, others are simply not working yet
			// 
			string[] errors = new string[]{
			// #pragma Options with INT and not STRING
			 "#pragma options(1,on)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x\n" // failure
			 // #pragma warnings with STRING and not INT
			, "#pragma warnings(\"az\",on)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x"		
			 // #pragma warnings with missing ON
			, "#pragma warnings(12345)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x"		
			 // #pragma warnings with missing ON
			, "#pragma warnings(12345,)\r\nFunction Main()\nLOCAL x as STRING\n x := 'aaa'\nRETURN x"		
			 // missing Endif
			, "function Foo(bars as ICollection) AS LOGIC\nFOREACH IMPLIED bar in bars\n if bar IS Foo\nRETURN TRUE\nNEXT\nRETURN False\n" 
			 // missing NEXT
			, "function Foo(bars as ICollection) AS LOGIC\nFOREACH IMPLIED bar in bars\n if bar IS Foo\nRETURN TRUE\nendif\nRETURN False\n" 
			 // Generic Class, failure keyword UNION
			,"CLASS Foo <T> WHERE T IS UNION  \n END CLASS\n"					
			 // User32.M is not recognized yet.
			, "_DLL FUNCTION MessageBox(hwnd AS PTR, lpText AS PSZ, lpCaption AS PSZ, uType AS DWORD) AS INT PASCAL:USER32.MessageBoxA"
			, "Function Foo()\nConsole.WriteLine(e\"\\c\\d\\e\\g\\h\\i\\j\")\n"
			, "Function Foo()\nConsole.WriteLine(e\"\\uGGGG\")\n"
			};

			foreach (String s in noerrors)
			{

				if (AnalyzeCode(s, true) != 0)
				{
					Console.WriteLine(s);
				}
			}
			foreach (String s in errors)
			{
				// Only report when no errors found
				if (AnalyzeCode(s, false) == 0)
				{
					Console.WriteLine(s);
				}
			}
			Console.WriteLine("Press Enter");
			Console.ReadLine();
		}
		static int AnalyzeCode(string code, bool showErrors)
		{
			var stream = new AntlrInputStream(code.ToString());
			var lexer = new XSharpLexer(stream);
			lexer.AllowFourLetterAbbreviations = true;
			var tokens = new CommonTokenStream(lexer);
			var parser = new XSharpParser(tokens);
			parser.AllowXBaseVariables = true;
			parser.VOSyntax = true;
			var errorListener = new XSharpErrorListener(showErrors);
			parser.AddErrorListener(errorListener);
			var tree = parser.source();
			return errorListener.TotalErrors;
		}
	}
	internal class XSharpErrorListener : IAntlrErrorListener<IToken>
	{
		public int TotalErrors { get; private set; }
		private bool _showErrors;
		internal XSharpErrorListener(bool ShowErrors)
		{
			TotalErrors = 0;
			_showErrors = ShowErrors;
		}
		public void SyntaxError(IRecognizer recognizer, IToken offendingSymbol, int line, int charPositionInLine, string msg, RecognitionException e)
		{

			TotalErrors += 1;
			if (_showErrors)
			{
				if (e?.OffendingToken != null)
				{
					Console.WriteLine("line :" + e.OffendingToken.Line + " column: " + e.OffendingToken.Column + " " + msg);
				}
				else
				{
					Console.WriteLine("line :" + line + 1 + " column: " + charPositionInLine + 1 + " " + msg);
				}
			}
		}
	}

}

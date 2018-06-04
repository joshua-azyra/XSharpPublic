﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.  
// Licensed under the Apache License, Version 2.0.  
// See License.txt in the project root for license information.
//
USING System
USING System.Collections.Generic
USING System.Linq
USING System.Text
using XUnit
using System.Globalization


BEGIN NAMESPACE XSharp.VO.Tests

	class TransFormTests

		[Fact, Trait("Category", "TransForm")];
		method LogicalTest() as void 
			// with @R other chars are appended, but only a single YN or TF flag is written. Other positions become a space
			Assert.Equal("Y", TransForm(true, "Y"))
			Assert.Equal("N", TransForm(false, "Y"))
			Assert.Equal("T", TransForm(true, "L"))
			Assert.Equal("F", TransForm(false, "L"))
			Assert.Equal("T x", TransForm(true, "@R L x"))
			Assert.Equal("F x", TransForm(false, "@R L x"))
			Assert.Equal("Y x", TransForm(true, "@R YYx"))
			Assert.Equal("N x", TransForm(FALSE, "@R YYx"))
			SetNatDLL("French.DLL")
			Assert.Equal("O", TransForm(true, "Y"))
			Assert.Equal("N", TransForm(false, "Y"))
			Assert.Equal("V", TransForm(true, "L"))
			Assert.Equal("F", TransForm(false, "L"))
			Assert.Equal("V x", TransForm(true, "@R L x"))
			Assert.Equal("F x", TransForm(false, "@R L x"))
			Assert.Equal("O x", TransForm(true, "@R YYx"))
			Assert.Equal("N x", TransForm(false, "@R YYx"))

		[Fact, Trait("Category", "TransForm")];
		method DateTest() as void 
			// with @R other chars are appended, but only a single YN or TF flag is written. Other positions become a space
			Assert.Equal("10/12/2010", TransForm(2010.12.10,"@E"))
			Assert.Equal("20/11/2010", TransForm(2010.11.20,"@E"))
			SetDateFormat("dd-mm-yyyy")
			Assert.Equal("20-11-2010", TransForm(2010.11.20,"@D"))
			SetDateFormat("dd-mm-yy")
			Assert.Equal("20-11-10", TransForm(2010.11.20,"@D"))

		[Fact, Trait("Category", "TransForm")];
		method StringTest() as void 
			Assert.Equal("ABC", Transform("abc", "@!"))
			Assert.Equal("AbC", Transform("abc", "!a!"))
			Assert.Equal("1234 AB", Transform("1234ab", "@R! 9999 AA"))
			Assert.Equal("1234 AB", Transform("1234ab", "@R 9999 !!"))

		[Fact, Trait("Category", "TransForm")];
		METHOD LongTest() AS VOID 
			SetDecimalSep('.')
			SetThousandSep(',')
			Assert.Equal("  1", Transform(1, "999"))
			Assert.Equal("123", Transform(123, "###"))
			Assert.Equal("**", Transform(123, "##"))			
			Assert.Equal("**", Transform(123, "99"))			
			Assert.Equal("(1)", Transform(-1, "@( 99"))
			Assert.Equal("(-1)", Transform(-1, "@( 999"))
			Assert.Equal("( -1)", Transform(-1, "@( 9999"))
			Assert.Equal("(-1)", Transform(-1, "@) 9999"))
			Assert.Equal(" (-1)", Transform(-1, "@) 99999"))
			Assert.Equal("   ", Transform(0, "@Z 999"))
			Assert.Equal(" -1 DB", Transform(-1, "@X 999"))
			Assert.Equal(" -1 DB", Transform(-1, "@XC 999"))
			Assert.Equal("  1 CR", Transform(1, "@XC 999"))
			Assert.Equal("  1 CR", Transform(1, "@C 999"))
			Assert.Equal("  0", Transform(0, "@C 999"))
			Assert.Equal("1,234", Transform(1234, "9,999"))
			SetDecimalSep(',')
			SetThousandSep('.')
			Assert.Equal("1.234", Transform(1234, "9,999"))


		[Fact, Trait("Category", "TransForm")];
		method FLoatTest() as void 
			SetDecimalSep('.')
			SetThousandSep(',')
			Assert.Equal("1.23", Transform(1.23, "9.99"))
			Assert.Equal("1,23", Transform(1.23, "@E 9.99"))
			Assert.Equal("*.**", Transform(12.34, "9.99"))			

// some new failing tests:
	[Fact, Trait("Category", "TransForm")];
	METHOD IntLiteralTest() AS VOID
		LOCAL dec AS dword
		LOCAL thou AS DWORD

		dec := SetDecimalSep(Asc(","))
		thou := SetThousandSep(Asc("."))
		Assert.Equal(" 12.345,00" , Transform(12345.0, "999,999.99"))
		// this fails:
		Assert.Equal(" 12.345,00" , Transform(12345, "999,999.99"))
        
		SetDecimalSep(Asc("."))
		SetThousandSep(Asc(","))
		Assert.Equal(" 12,345.00" , Transform(12345.0, "999,999.99"))
		Assert.Equal(" 12,345.00" , Transform(12345, "999,999.99"))

		SetDecimalSep(dec)
		SetThousandSep(thou)
	RETURN



// Tests that need to be moved in separate files in VO.Tests:
	[Fact, Trait("Category", "StringEq")];
	METHOD StringEquality() AS VOID
		LOCAL c1,c2 AS STRING
		LOCAL u1,u2 AS USUAL
		local exact as LOGIC
		u1 := c1 := "TESTLONG"
		u2 := c2 := "TEST"
		exact := SetExact( FALSE )
		
		Assert.Equal(true, c1 = c2)
		Assert.Equal(true, c1 != c2)

		Assert.Equal(true, u1 = u2)
		Assert.Equal(false, u1 != u2)

		SetExact( exact )	
	RETURN

	[Fact, Trait("Category", "Str")];
	METHOD StrTests() AS VOID
		local exact,thou,digit,decimal,fixed_,digitfixed as usual
		exact := SetDecimalSep(Asc("."))
		thou := SetThousandSep(Asc(","))
		digit := SetDigit(6)
		decimal := SetDecimal(3)
		fixed_ := SetFixed(FALSE)
		digitfixed := SetDigitFixed(FALSE)

		Assert.Equal( "     1.2"			, Str(1.2) )
		Assert.Equal( "    12.3"			, Str(12.3) )
		Assert.Equal( "    12.34"			, Str(12.34) )
		Assert.Equal( "   123.456"			, Str(123.456) )
		Assert.Equal( "  1234.567"			, Str(1234.567) )
		Assert.Equal( "  1234.5678"			, Str(1234.5678) )
		Assert.Equal( "  1234.5679012345"	, Str(1234.5679012345) )
		Assert.Equal( "123456.78901234567"	, Str(123456.78901234567) )
		Assert.Equal( "999999" , Str(999999) )
		Assert.Equal( "******" , Str(1000000) )

		SetDecimalSep(exact)
		SetThousandSep(thou)
		SetDigit(digit)
		SetDecimal(decimal)
		SetFixed(fixed_)
		SetDigitFixed(digitfixed)
	RETURN

	[Fact, Trait("Category", "Val")];
	METHOD ValTests() AS VOID
		Assert.Equal(true, Val("123") == 123)
		Assert.Equal(true, Val("123.456") == 123.456)

		Assert.Equal(true, Val("") == 0)
		Assert.Equal(true, Val("") == 0.0)

		Assert.Equal(true, Val("abc") == 0)
		Assert.Equal(true, Val("123abc") == 123)
		Assert.Equal(true, Val("123abc456") == 123)
		Assert.Equal(true, Val("123abc456.789") == 123)
		Assert.Equal(true, Val("abc123456.789") == 0)
	RETURN

	[Fact, Trait("Category", "SplitPath")];
	METHOD SplitPathTests() AS VOID
		LOCAL cDrive := "",cDir := "",cFile := "",cExt := "" AS STRING
		SplitPath("C:\folder\file.ext" , cDrive , cDir , cFile , cExt)
		
		Assert.Equal("C:" , cDrive)
		Assert.Equal("\folder\" , cDir)

		Assert.Equal("file" , cFile)
		Assert.Equal(".ext" , cExt)
	RETURN

	[Fact, Trait("Category", "SplitPathVO")];
	METHOD SplitPathVO() AS VOID
		LOCAL cPath ,cDrive ,cDir ,cFile ,cExt AS STRING
		LOCAL pszDrive, pszDir AS PSZ
		LOCAL pszFile, pszExt AS PSZ
	
		cPath := "C:\testfolder\testfile.prg"
	
		pszDrive := MemAlloc(2+1)
		pszDir   := MemAlloc(255+1)
		pszFile  := MemAlloc(255+1)
		pszExt   := MemAlloc(7+1) 
	
		SplitPath(String2Psz(cPath), pszDrive, pszDir,        ;
			 pszFile, pszExt)
	
		cDrive := Psz2String(pszDrive)
		cDir   := Psz2String(pszDir)
		cFile  := Psz2String(pszFile)
		cExt   := Psz2String(pszExt)
	
		MemFree(pszDrive)
		MemFree(pszDir)
		MemFree(pszFile)
		MemFree(pszExt)
	
		Assert.Equal("\testfolder\" , cDir)
		Assert.Equal("\testfolder\" , cDir)
		Assert.Equal("testfile" , cFile)
		Assert.Equal(".prg" , cExt)
	RETURN

	end class
end NAMESPACE
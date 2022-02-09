﻿
//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
USING System
USING System.Collections.Generic
USING System.Linq
USING System.Text
USING XUnit

using System.Diagnostics

// Array tests are not working correctly yet with the current build
BEGIN NAMESPACE XSharp.RT.Tests

	CLASS NullTests
		STATIC CONSTRUCTOR
        XSharp.RuntimeState.Dialect := XSharpDialect.FoxPro

		[Fact, Trait("Category", "Null")];
		METHOD UsualNullTests() AS VOID
            LOCAL u1, u2 as USUAL
            u1 := DBNull.Value
            u2 := 42
            Assert.Equal( u1 > u2, FALSE)
            Assert.Equal( u1 >= u2, FALSE)
            Assert.Equal( u1 < u2, TRUE)
            Assert.Equal( u1 <= u2, TRUE)
            Assert.Equal( u1 == u2, FALSE)
            Assert.Equal( u1 != u2, TRUE)

            Assert.Equal( u2 > u1, TRUE)
            Assert.Equal( u2 >= u1, TRUE)
            Assert.Equal( u2 < u1, FALSE)
            Assert.Equal( u2 <= u1, FALSE)
            Assert.Equal( u1 == u2, FALSE)
            Assert.Equal( u1 != u2, TRUE)


            u2 := "X# Rules"
            Assert.Equal( u1 > u2, FALSE)
            Assert.Equal( u1 >= u2, FALSE)
            Assert.Equal( u1 < u2, TRUE)
            Assert.Equal( u1 <= u2, TRUE)
            Assert.Equal( u1 == u2, FALSE)
            Assert.Equal( u1 != u2, TRUE)

            Assert.Equal( u2 > u1, TRUE)
            Assert.Equal( u2 >= u1, TRUE)
            Assert.Equal( u2 < u1, FALSE)
            Assert.Equal( u2 <= u1, FALSE)
            Assert.Equal( u1 == u2, FALSE)
            Assert.Equal( u1 != u2, TRUE)


            u2 := DBNull.Value
            Assert.Equal( u1 > u2, FALSE)
            Assert.Equal( u1 >= u2, TRUE)
            Assert.Equal( u1 < u2, FALSE)
            Assert.Equal( u1 <= u2, TRUE)
            Assert.Equal( u1 == u2, TRUE)
            Assert.Equal( u1 != u2, FALSE)
            // calculations
            u2 := 42
            Assert.True( (u1 + u2) == DBNUll.Value)
            Assert.True( (u1 - u2) == DBNUll.Value)
            Assert.True( (u1 * u2) == DBNUll.Value)
            Assert.True( (u1 / u2) == DBNUll.Value)
            Assert.True( (u1 % u2) == DBNUll.Value)

            u2 := "X# Rules"
            Assert.True( (u1 + u2) == DBNUll.Value)
            Assert.True( (u1 - u2) == DBNUll.Value)
            Assert.True( (u1 * u2) == DBNUll.Value)
            Assert.True( (u1 / u2) == DBNUll.Value)
            Assert.True( (u1 % u2) == DBNUll.Value)


            u1 := 42
            u2 := DBNull.Value
            Assert.True( (u1 + u2) == DBNUll.Value)
            Assert.True( (u1 - u2) == DBNUll.Value)
            Assert.True( (u1 * u2) == DBNUll.Value)
            Assert.True( (u1 / u2) == DBNUll.Value)
            Assert.True( (u1 % u2) == DBNUll.Value)

            u1 := DBNull.Value
            Assert.True( +u1 == DBNull.Value)
            Assert.True( -u1 == DBNull.Value)
            Assert.True( ++u1 == DBNull.Value)
            Assert.True( --u1 == DBNull.Value)
            Assert.True( u1++ == DBNull.Value)
            Assert.True( u1-- == DBNull.Value)

            Assert.True( u1<<10 == DBNull.Value)
            Assert.True( u1>>10 == DBNull.Value)

            Assert.False(IsNil(u1))
            Assert.True(ValType(u1) == "X")
            Assert.True(UsualType(u1) == (LONG) __UsualType.Null)




	END CLASS



END NAMESPACE

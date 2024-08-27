// 917. Some issues with /allowdot-
// https://github.com/X-Sharp/XSharpPublic/issues/1515#issuecomment-2313065234

// core dialect, /allowdot- (disabled)
FUNCTION Start( ) AS VOID
RETURN

ENUM MyEnum 
	MEMBER m1
	MEMBER m2
END ENUM

CLASS FirstClass
	PROPERTY MyEnum AS MyEnum AUTO

	STATIC METHOD Test() AS VOID
		// error XS0176: Member 'MyEnum.m1' cannot be accessed with an instance reference; qualify it with a type name instead
		LOCAL e := MyEnum.m1 AS MyEnum // error XS0176
		IF e == MyEnum.m1 // error XS0176
			NOP
		END IF

// no error reported for code inside an instance method:
	METHOD InstanceTest() AS VOID
		LOCAL e := MyEnum.m1 AS MyEnum // no error
		IF e == MyEnum.m1 // no error
			NOP
		END IF

END CLASS


CLASS ContainerClass
	EXPORT myEnum AS INT
	EXPORT AnotherTest AS AnotherTest

	CLASS NestedClass
		METHOD Test() AS VOID
			// No error reported on this code, but causes failed to emit module error
			MyEnum.m1:ToString()
			LOCAL e := MyEnum.m1 AS MyEnum
			IF e == MyEnum.m1
				NOP
			END IF
			
			// error XS0176: Member 'AnotherTest.StaticMethod()' cannot be accessed with an instance reference; qualify it with a type name instead
			AnotherTest.StaticMethod()
	END CLASS
	
END CLASS

CLASS AnotherTest
	STATIC METHOD StaticMethod() AS VOID
END CLASS


FUNCTION Start( ) AS VOID
	LOCAL oName AS IName
	LOCAL uName AS USUAL
	oName := Person{}   
	uName := oName
	? uName
	

RETURN


INTERFACE IName
	PROPERTY Name AS STRING GET SET
END INTERFACE


CLASS Person IMPLEMENTS IName
	PROPERTY Name AS STRING AUTO
END CLASS

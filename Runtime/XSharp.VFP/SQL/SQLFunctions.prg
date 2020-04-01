﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
USING System.Collections.Generic 
USING System
USING XSharp.VFP


/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlconnect/*" />
FUNCTION SqlConnect(uSource , cUserID , cPassword , lShared) AS LONG
    // uSource may be either a DSN or a nStatementHandle
    LOCAL nHandle := -1 AS LONG
    LOCAL cSource AS STRING
    LOCAL oStmt AS XSharp.VFP.SQLStatement
    IF IsNumeric(uSource)
        IF ! IsNil(cUserID) .OR. ! IsNil(cPassword) .OR. ! IsNil(lShared)
           THROW Error{"Number or type of parameters is not correct"}
        ENDIF
        nHandle     := uSource
        oStmt := SQLSupport.FindStatement(nHandle)
        IF oStmt == NULL_OBJECT
            THROW Error{"Statement Handle ("+nHandle:ToString()+") is invalid"}
        ENDIF
        // This should open a connection automatically since the previous connection as already validated
        IF ! oStmt:Connection:Shared
            THROW Error{"Statement Handle ("+nHandle:ToString()+") does not have a shared connection"}
        ENDIF
        oStmt := XSharp.VFP.SQLStatement{oStmt:Connection}
        SQLSupport.AddStatement(oStmt)

    ELSEIF IsString(uSource)
        // if one or more parameters are missing then the connect dialog is shown
        cSource := uSource
        IF ! IsString(cUserID) ; cUserID := "" ; ENDIF
        IF ! IsString(cPassword) ; cPassword := "" ; ENDIF
        IF ! IsLogic(lShared) ; lShared := TRUE ; ENDIF
        oStmt := XSharp.VFP.SQLStatement{cSource, cUserID, cPassword, lShared}
        nHandle := SQLSupport.AddStatement(oStmt)
    ENDIF
    RETURN nHandle
    

/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlstringconnect/*" />

FUNCTION SqlStringConnect( uSharedOrConnectString, lSharable) AS LONG
    //  uSharedOrConnectString may be either lShared or a connection string
    // in FoxPro when passing lShared as TRUE then the "Select Connection or Data Source Dialog Box"  is shown
    // This is the normal 'DriverConnect' dialog for ODBC drivers
    LOCAL nHandle := -1 AS LONG
    LOCAL oStmt AS XSharp.VFP.SQLStatement
    IF IsLogic(uSharedOrConnectString)
        // show connection string dialog
       oStmt := XSharp.VFP.SQLStatement{"", uSharedOrConnectString}
    ELSEIF IsString(uSharedOrConnectString)
       IF ! IsLogic(lSharable) ; lSharable := TRUE ; ENDIF
       oStmt := XSharp.VFP.SQLStatement{uSharedOrConnectString,lSharable}
    ELSE
       THROW Error{"Number or type of parameters is not correct"}
    ENDIF
    IF oStmt:Connected
        nHandle := SQLSupport.AddStatement(oStmt)
    ENDIF
    RETURN nHandle
  
    



/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlcancel/*" />

FUNCTION SQLCANCEL( nStatementHandle) AS LONG
    THROW NotImplementedException{}
    // RETURN 0

/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlcolumns/*" />

FUNCTION SqlColumns( nStatementHandle, cTableName, cType, cCursorName) AS USUAL
    THROW NotImplementedException{}
    // RETURN NIL

/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlcommit/*" />

FUNCTION SqlCommit( nStatementHandle ) AS LONG
    THROW NotImplementedException{}
    // RETURN 0

/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlconnect/*" />



/// <include file="VFPDocs.xml" path="Runtimefunctions/sqldisconnect/*" />
FUNCTION SqlDisconnect( nStatementHandle AS LONG) AS LONG
    LOCAL oStmt AS XSharp.VFP.SQLStatement
    oStmt := SQLSupport.FindStatement(nStatementHandle)
    IF oStmt != NULL
        SQLSupport.RemoveStatement(nStatementHandle)
        oStmt:DisConnect()
        RETURN 1
    ENDIF
    RETURN -1

/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlexec/*" />

FUNCTION SqlExec( nStatementHandle , cSQLCommand , cCursorName, aCountInfo) AS LONG
    LOCAL oStmt AS XSharp.VFP.SQLStatement
    LOCAL aInfo AS ARRAY
    LOCAL prepared := FALSE AS LOGIC
    IF !IsLong(nStatementHandle)
        THROW Error{"Number or type of parameters is not correct"}
    ENDIF
    IF ! IsString(cCursorName)
        cCursorName := "SQLRESULT"
    ENDIF
    oStmt := SQLSupport.FindStatement(nStatementHandle)
    IF oStmt != NULL
        IF !IsString(cSQLCommand)
            IF ! oStmt:Prepared
                THROW Error{"SQL Statement parameter is required for non prepared SQL Statements"}
            ENDIF
            prepared := TRUE
        ENDIF
        LOCAL result AS LONG
        aInfo := {}
        IF prepared
            result := oStmt:Execute(aInfo)
        ELSE
            result := oStmt:Execute(cSQLCommand, cCursorName, aInfo)
        ENDIF
        
        IF IsArray(aCountInfo)
            ASize(aCountInfo, ALen(aInfo))
            ACopy(aInfo, aCountInfo)
        ENDIF
        RETURN result
    ENDIF
    RETURN 0
    
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlgetprop/*" />
FUNCTION SqlGetProp( nStatementHandle, cSetting ) AS USUAL
    RETURN SQLSupport.GetSetProperty(nStatementHandle, cSetting,NULL)
    // RETURN NIL

/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlidledisconnect/*" />

FUNCTION SqlIdleDisconnect( nStatementHandle) AS LONG
    THROW NotImplementedException{}
    // RETURN 0

/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlmoreresults/*" />

FUNCTION SqlMoreResults( nStatementHandle , cCursorName , aCountInfo) AS LONG
    THROW NotImplementedException{}
    // RETURN 0

/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlprepare/*" />
FUNCTION SqlPrepare( nStatementHandle, cSQLCommand, cCursorName) AS LONG
    LOCAL oStmt AS XSharp.VFP.SQLStatement
    IF !IsLong(nStatementHandle) .OR. ! IsString(cSQLCommand)
        THROW Error{"Number or type of parameters is not correct"}
    ENDIF
    IF ! IsString(cCursorName)
        cCursorName := "SQLRESULT"
    ENDIF
    oStmt := SQLSupport.FindStatement(nStatementHandle)
    IF oStmt != NULL
        VAR result := oStmt:Prepare(cSQLCommand, cCursorName)
        RETURN result
    ENDIF
    RETURN 0

/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlrollback/*" />

FUNCTION SqlRollBack( nStatementHandle ) AS LONG
    THROW NotImplementedException{}
    // RETURN 0

/// <include file="VFPDocs.xml" path="Runtimefunctions/sqlsetprop/*" />
FUNCTION SqlSetProp( nStatementHandle, cSetting , eExpression) AS LONG
    RETURN (INT) SQLSupport.GetSetProperty(nStatementHandle, cSetting,eExpression)



/// <summary>-- todo --</summary>
/// <include file="VFPDocs.xml" path="Runtimefunctions/sqltables/*" />

FUNCTION SqlTables( nStatementHandle , cTableTypes , cCursorName) AS LONG
    THROW NotImplementedException{}
    // RETURN 0



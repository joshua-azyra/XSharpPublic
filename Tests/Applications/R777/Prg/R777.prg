// R777 IS Pattern Check with USUAL values  
// Also Switch Pattern Check with USUAL values
// #https://github.com/X-Sharp/XSharpPublic/issues/636

FUNCTION Start( ) AS VOID

    LOCAL uValue := GetObject(2)
    IF uValue IS Error VAR oError
        ? "Error", oError:Message
    ELSEIF uValue IS STRING VAR strValue
        ? "String", strValue
    ENDIF
    SWITCH uValue
    CASE oError AS Error 
        ? "Error", oError:Message
    CASE strValue AS STRING 
        ? "String", strValue
    END SWITCH
    WAIT


RETURN




FUNCTION GetObject(nType AS INT) AS USUAL
    SWITCH nType
    CASE 1
        RETURN Error{"test"}
    CASE 2
        RETURN "abc"
    END SWITCH
    RETURN OBJECT{}        

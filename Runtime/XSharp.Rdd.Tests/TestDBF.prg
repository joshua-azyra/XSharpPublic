﻿// TestDBF.prg
// Created by    : fabri
// Creation Date : 4/24/2018 5:21:57 PM
// Created for   : 
// WorkStation   : FABPORTABLE


USING System
USING System.Collections.Generic
USING System.Text
USING Xunit
USING XSharp.RDD

BEGIN NAMESPACE XSharp.RDD.Tests
    
    /// <summary>
    /// The TestDBF class.
    /// </summary>
    CLASS TestDBF
        
        [Fact, Trait("Dbf", "Open")];
            METHOD OpenDBF() AS VOID
            // CUSTNUM,N,5,0	FIRSTNAME,C,10	LASTNAME,C,10	ADDRESS,C,25	CITY,C,15	STATE,C,2	ZIP,C,5	PHONE,C,13	FAX,C,13
            VAR dbInfo := DbOpenInfo{ "customer.DBF", "customer", 1, FALSE, FALSE }
            //
            VAR myDBF := DBF{}
            Assert.Equal( TRUE, myDBF:Open( dbInfo ) )
            //
            myDBF:Close()
            RETURN
        
        [Fact, Trait("Dbf", "Close")];
            METHOD CloseDBF() AS VOID
            // CUSTNUM,N,5,0	FIRSTNAME,C,10	LASTNAME,C,10	ADDRESS,C,25	CITY,C,15	STATE,C,2	ZIP,C,5	PHONE,C,13	FAX,C,13
            VAR dbInfo := DbOpenInfo{ "customer.DBF", "customer", 1, FALSE, FALSE }
            //
            VAR myDBF := DBF{}
            IF myDBF:Open( dbInfo )
                // Should FAIL as currently no ClearScope, ClearRel, ...
                Assert.Equal( TRUE, myDBF:Close() )
            ENDIF
            RETURN
        
        [Fact, Trait("Dbf", "Fields")];
            METHOD CheckFields() AS VOID
            VAR fields := <STRING>{ "CUSTNUM", "FIRSTNAME", "LASTNAME","ADDRESS","CITY","STATE","ZIP", "PHONE", "FAX" }
            VAR types :=  <STRING>{ "N", "C", "C","C","C","C","C", "C", "C" }
            // CUSTNUM,N,5,0	FIRSTNAME,C,10	LASTNAME,C,10	ADDRESS,C,25	CITY,C,15	STATE,C,2	ZIP,C,5	PHONE,C,13	FAX,C,13
            VAR dbInfo := DbOpenInfo{ "customer.DBF", "customer", 1, FALSE, FALSE }
            //
            VAR myDBF := DBF{}
            IF myDBF:Open( dbInfo ) 
                //
                // Right number of Fields ?
                Assert.Equal(Fields:Length, myDBF:FieldCount)
                FOR VAR i := 1 TO myDBF:FIELDCount
                    // Right Name decoding ?
                    Assert.Equal( fields[i], myDBF:FieldName( i ) )
                    // Right Type decoding ?
                    //Assert.Equal( types[i], myDBF:FieldName( i ) )
                NEXT
                //
                myDBF:Close()
            ENDIF

        RETURN        
    END CLASS
END NAMESPACE // XSharp.RDD.Tests
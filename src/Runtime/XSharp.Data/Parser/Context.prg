USING System.Collections.Generic
USING System.Text
using System.Diagnostics
using XSharp.RDD.Support
using XSharp.RDD.Enums

BEGIN NAMESPACE XSharp.Parsers

[DebuggerDisplay("{Type,nq} {Name,nq}")];
CLASS FoxCreateTableContext
    PROPERTY Name       as STRING AUTO
    PROPERTY IsCursor   AS LOGIC AUTO
    PROPERTY Type       as STRING => IIF(IsCursor, "CURSOR","TABLE")
    PROPERTY Columns    as List<FoxCreateColumnContext> AUTO
    PROPERTY CodePage   as LONG AUTO
    PROPERTY ArrayName  as STRING AUTO
    PROPERTY RuleExpression as STRING AUTO
    PROPERTY RuleText       as string Auto
    CONSTRUCTOR()
        SELF:Columns := List<FoxCreateColumnContext>{}
        RETURN

    OVERRIDE METHOD ToString() AS STRING
        var sb := StringBuilder{}
        sb:Append(Type)
        sb:Append(" ")
        sb:Append(Name)
        sb:Append(" ")
        if ! String.IsNullOrEmpty(RuleExpression)
            sb:Append("Check "+RuleExpression)
        ENDIF
        return sb:ToString()
        END CLASS

[DebuggerDisplay("{Name,nq} {FieldType}")];
CLASS FoxCreateColumnContext INHERIT RddFieldInfo
    PROPERTY Foreign    as STRING AUTO
    PROPERTY ForeignTag AS STRING AUTO
    PROPERTY Table      AS FoxCreateTableContext AUTO GET PRIVATE SET
    CONSTRUCTOR (oTable as FoxCreateTableContext)
        SUPER("",DbFieldType.Unknown,0,0)
        SELF:Table := oTable
        RETURN

    OVERRIDE METHOD ToString() AS STRING
        var sb := StringBuilder{}
        sb:Append(SELF:Name)
        sb:Append(" ")
        sb:Append(SELF:FieldType:ToString())
        IF SELF:Length > 0
            sb:Append("(")
            sb:Append(SELF:Length)
            IF SELF:Decimals > 0
                sb:Append(",")
                sb:Append(SELF:Decimals)
            ENDIF
            sb:Append(")")

        ENDIF
        if SELF:IsNullable
            sb:Append(" Null")
        endif
        if SELF:IsUnique
            sb:Append(" Unique")
        endif
        if SELF:PrimaryKey
            sb:Append(" Primary key")
        endif
        if !String.IsNullOrEmpty(SELF:DefaultValue)
            sb:Append(" Default " +SELF:DefaultValue)
        endif
        if !String.IsNullOrEmpty(SELF:RuleExpression)
            sb:Append(" Check " +SELF:RuleExpression)
            if !String.IsNullOrEmpty(SELF:RuleText)
                sb:Append(" Error " +SELF:RuleText)
            endif
        endif
        return sb:ToString()

END CLASS

CLASS FoxDeleteContext
    PROPERTY TableName  AS STRING AUTO
    PROPERTY IsForce    AS LOGIC AUTO
    PROPERTY TableList  AS List<STRING> AUTO
    PROPERTY JoinList   AS List<STRING> AUTO
    PROPERTY WhereClause AS STRING AUTO
    CONSTRUCTOR()
        IsForce   := FALSE
        TableList := List<String>{}
        JoinList  := List<String>{}
        RETURN

END CLASS
CLASS FoxUpdateContext
    PROPERTY TableName   AS STRING AUTO
    PROPERTY ColumnList  AS List<STRING> AUTO
    PROPERTY ValueList   AS List<STRING> AUTO
    PROPERTY IsForce    AS LOGIC AUTO
    PROPERTY TableList  AS List<STRING> AUTO
    PROPERTY JoinList   AS List<STRING> AUTO
    PROPERTY WhereClause AS STRING AUTO
    CONSTRUCTOR()
        IsForce   := FALSE
        ColumnList := List<String>{}
        ValueList := List<String>{}
        TableList := List<String>{}
        JoinList  := List<String>{}
        RETURN

END CLASS
END NAMESPACE

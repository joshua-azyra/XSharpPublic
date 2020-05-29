﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//

// Note that the comment blocks from the various rules have been copied from XSharp.g4 inside the compiler

USING System.Collections.Generic
USING System.Collections
USING System.Text
USING System.Text.RegularExpressions
USING System.IO
USING System.Diagnostics
USING System.Linq
USING LanguageService.CodeAnalysis.XSharp
USING LanguageService.SyntaxTree
USING LanguageService.CodeAnalysis.XSharp.SyntaxParser
USING XSharp.Parser
USING LanguageService.CodeAnalysis.Text

BEGIN NAMESPACE XSharpModel
   
   
   PARTIAL CLASS ParserV2 IMPLEMENTS VSParser.IErrorListener
      
      PRIVATE  _input        AS IList<IToken>
      PRIVATE  _index        AS LONG
      PRIVATE  _file         AS XFile
      PRIVATE  _usings       AS IList<STRING>
      PRIVATE  _staticusings AS IList<STRING>
      PRIVATE  _EntityList    AS IList<XElement>
      PRIVATE  _EntityStack   AS Stack<XElement>
      PRIVATE  _BlockList     AS IList<XBlock>
      PRIVATE  _BlockStack    AS Stack<XBlock>
      PRIVATE  _PPBlockStack  AS Stack<XBlock>
      PRIVATE  _locals        AS IList<XVariable>
      PRIVATE  _lastToken     AS IToken
      PRIVATE  _collectLocals  AS LOGIC 
      PRIVATE  _collectBlocks  AS LOGIC
	   PRIVATE  _errors AS IList<XError>
      PRIVATE _globalType     AS XType

      PRIVATE  _mods         AS Modifiers      // for the current entity
      PRIVATE  _vis          AS Modifiers      // for the current entity
      PRIVATE  _start        AS IToken
      
      PRIVATE PROPERTY CurrentEntity      AS Xelement GET IIF(_EntityStack:Count > 0, _EntityStack:Peek(), NULL_OBJECT)
      PRIVATE PROPERTY CurrentBlock       AS XBlock   GET IIF(_BlockStack:Count > 0, _BlockStack:Peek(), NULL_OBJECT)
      PRIVATE PROPERTY CurrentEntityKind  AS Kind     GET IIF(_EntityStack:Count > 0, CurrentEntity:Kind, Kind:Unknown)
      PRIVATE PROPERTY La1 AS INT GET SELF:La(1)
      PRIVATE PROPERTY La2 AS INT GET SELF:La(2)
      PRIVATE PROPERTY La3 AS INT GET SELF:La(3)
      PRIVATE PROPERTY Lt1 AS IToken GET SELF:Lt(1)
      PRIVATE PROPERTY Lt2 AS IToken GET SELF:Lt(2)
      PRIVATE PROPERTY Lt3 AS IToken GET SELF:Lt(3)
      PRIVATE PROPERTY lastToken AS IToken GET _lastToken
      
      PROPERTY EntityList AS IList<XElement>  GET _EntityList
      PROPERTY BlockList  AS IList<XBlock>    GET _BlockList
      PROPERTY Locals     AS IList<XVariable> GET _locals
      
      
      CONSTRUCTOR(oFile AS XFile)
         _errors        := List<XError>{}
         _usings        := List<STRING>{}
         _staticusings  := List<STRING>{}
         _EntityList    := List<XElement>{}
         _EntityStack   := Stack<XElement>{}
         _BlockList     := List<XBlock>{}
         _BlockStack    := Stack<XBlock>{}
         _PPBlockStack  := Stack<XBlock>{}
         _file          := oFile
         _locals        := List<XVariable>{}
         _globalType    := XType.CreateGlobalType(_file)
         _EntityStack:Push(_globalType)

      
      #region IErrorListener
			VIRTUAL METHOD ReportError(fileName AS STRING, span AS LinePositionSpan, errorCode AS STRING, message AS STRING, args AS OBJECT[]) AS VOID
				SELF:_errors:Add(XError{fileName, span, errorCode, message, args})

			VIRTUAL METHOD ReportWarning(fileName AS STRING, span AS LinePositionSpan, errorCode AS STRING, message AS STRING, args AS OBJECT[]) AS VOID
				SELF:_errors:Add(XWarning{fileName, span, errorCode, message, args})
      #endregion

      METHOD Parse(lBlocks AS LOGIC, lLocals AS LOGIC) AS VOID
         VAR cSource  := System.IO.File.ReadAllText(_file:SourcePath) 
         VAR options  := XSharpParseOptions.Default
			XSharp.Parser.VsParser.Lex(cSource, SELF:_file:SourcePath, options, SELF, OUT VAR stream)
         SELF:Parse(stream, lBlocks, lLocals)
         RETURN 
    
      METHOD Parse( tokenStream AS ITokenStream, lBlocks AS LOGIC, lLocals AS LOGIC) AS VOID
         LOCAL nMods  AS Modifiers
         LOCAL nVis   AS Modifiers
         LOCAL aAttribs AS IList<IToken>
         _collectLocals := lLocals
         _collectBlocks := lBlocks
         LOCAL stream  := (BufferedTokenStream) tokenStream AS BufferedTokenStream
         VAR tokens    := stream:GetTokens()
         _input        := tokens:Where ({ t => t:Channel == 0 .OR. t:Channel == 4}):ToArray()
         
         _index := 0
         DO WHILE ! SELF:Eoi()
            VAR tokenBefore := lastToken
            VAR first := Lt1
            IF ParsePPLine()
               LOOP
            ENDIF
            IF SELF:ParseUsing()
               LOOP
            ENDIF
            aAttribs := ParseAttributes()
            VAR mods := ParseVisibilityAndModifiers()
            nVis := _AND(mods, Modifiers.VisibilityMask)
            IF nVis == Modifiers.None
               nVis := Modifiers.Public
            ENDIF
            nMods := _AND(mods, ~Modifiers.VisibilityMask)
            IF IsStartOfEntity(OUT VAR entityKind, mods)
               SELF:_mods  := nMods
               SELF:_vis   := nVis
               SELF:_start := first
               VAR entities := ParseEntity(entityKind)
               IF entities != NULL
                  
                  
                  FOREACH VAR entity IN entities
                     IF entity == NULL
                        LOOP
                     ENDIF
                     entity:File := _file
                     IF aAttribs?:Count > 0
                        entity:Attributes := TokensAsString(aAttribs)
                     ENDIF
                     VAR lastEntity := _EntityList:LastOrDefault()
                     IF lastEntity != NULL
                        lastEntity:Range       := lastEntity:Range:WithEnd(tokenBefore)
                        lastEntity:Interval    := lastEntity:Interval:WithEnd(tokenBefore)
                     ENDIF
                     _EntityList:Add(entity)
                  
                     IF _EntityStack:Count > 0 .AND. (!CurrentEntityKind:HasChildren() .OR. !(CurrentEntity IS XType ) )
                        _EntityStack:Pop()
                     ENDIF
                     IF entityKind:IsGlobalType() .AND. entity IS XTypeMember VAR xGlobalMember
                        SELF:_globalType:AddMember(xGlobalMember)
                     ELSE
                        IF CurrentEntityKind:HasChildren() .AND. CurrentEntity IS XType VAR xEnt
                           IF entity IS XTypeMember VAR xMember
                              xEnt:AddMember( xMember )
                           ELSEIF entity IS XType VAR xChild .AND. ! XType.IsGlobalType(xEnt)
                              xEnt:AddChild( xChild )
                              xChild:NameSpace := xEnt:FullName
                           ENDIF
                        ENDIF
                     ENDIF
                     IF ! entity:SingleLine                        
                        _EntityStack:Push(entity)
                     ENDIF
                     _BlockStack:Clear()
                  NEXT
               ELSE
                  NOP
               ENDIF
            ELSEIF IsEndOfEntity( OUT VAR endKind)
               VAR type := La2
               // match la2 with current entity
               DO WHILE TRUE .AND. _EntityStack:Count > 0
                  VAR top := _EntityStack:Pop()
                  IF top:Kind != endKind
                     top:Range       := top:Range:WithEnd(tokenBefore)
                     top:Interval    := top:Interval:WithEnd(tokenBefore)
                     LOOP
                  ENDIF
                  top:Range       := top:Range:WithEnd(lt2)
                  top:Interval    := top:Interval:WithEnd(lt2)
                  EXIT
               ENDDO
               SELF:ReadLine()
            ELSEIF ParseBlock()
               NOP               
            ELSE
               SELF:ParseStatement() 
            ENDIF
         ENDDO
         VAR types := SELF:_EntityList:Where( {x => x IS XType})
         VAR typelist := Dictionary<STRING, XType>{System.StringComparer.InvariantCultureIgnoreCase}
         typeList:Add(_globalType:Name, _globalType)
         FOREACH type AS XType IN types
            IF ! typelist:ContainsKey(type:Name)
               type:File := _file
               typelist:Add(type:Name, type)
            ENDIF
         NEXT
         _file:SetTypes(typeList, _usings, _staticusings, SELF:_EntityList)
         
         
         
      PRIVATE METHOD ParsePPLine() AS LOGIC
         VAR token := La1
         SWITCH La1
            CASE XSharpLexer.PP_REGION
            CASE XSharpLexer.PP_IFDEF
         CASE XSharpLexer.PP_IFNDEF
            VAR block := XBlock{ Lt1, Lt2}
            _BlockList:Add(block)
            _PPBlockStack:Push(block)
         CASE XSharpLexer.PP_ENDREGION
         CASE XSharpLexer.PP_ENDIF
               // end
            IF _PPBlockStack:Count > 0
               _PPBlockStack:Peek():Children:Add( XBlock{Lt1,Lt2})
               _PPBlockStack:Pop()
            ENDIF
         CASE XSharpLexer.PP_ELSE
               // middle
            IF _PPBlockStack:Count > 0
               _PPBlockStack:Peek():Children:Add( XBlock{Lt1,Lt2})
            ENDIF
         OTHERWISE
            RETURN FALSE
         END SWITCH
         ReadLine()
         RETURN TRUE
         
      PRIVATE METHOD ParseUsing() AS LOGIC
/*
using_              : USING (Static=STATIC)? (Alias=identifierName Op=assignoperator)? Name=name EOS
                    ;

*/         
         
         IF La1 != XSharpLexer.USING
            RETURN FALSE
         ENDIF
         VAR startToken := ConsumeAndGet()
         VAR isStatic := FALSE
         VAR alias := ""
         IF La1 == XSharpLexer.STATIC
            isStatic := TRUE
            SELF:Consume()
         ENDIF
         IF IsId(La1) .AND. SELF:IsAssignOp(La2)
            // name :=
            alias := SELF:ConsumeAndGettext()
            SELF:Consume()   // := 
         ENDIF
         VAR name := SELF:ParseQualifiedName()
         IF isStatic
            SELF:_staticusings:Add(name)
         ELSE
            SELF:_usings:Add(name)
         ENDIF
         ReadLine()
         RETURN TRUE
         
      PRIVATE METHOD ParseAttributes() AS IList<IToken>
/*
attributes          : ( AttrBlk+=attributeBlock )+
                    ;

attributeBlock      : LBRKT Target=attributeTarget? Attributes+=attribute (COMMA Attributes+=attribute)* RBRKT
                    | String=BRACKETED_STRING_CONST
                    ;

attributeTarget     : Token=(ID | CLASS | CONSTRUCTOR | DELEGATE | ENUM | EVENT | FIELD | INTERFACE | METHOD | PROPERTY  | RETURN | STRUCTURE ) COLON
                    ;

attribute           : Name=name (LPAREN (Params+=attributeParam (COMMA Params+=attributeParam)* )? RPAREN )?
                    ;

attributeParam      : Name=identifierName Op=assignoperator Expr=expression     #propertyAttributeParam
                    | Expr=expression                                   #exprAttributeParam
                    ;

*/         
         VAR tokens := List<IToken>{}
         DO WHILE La1 == XSharpLexer.LBRKT .AND. ! EoS() 
            tokens:Add(ConsumeAndGet())
            DO WHILE La1 != XSharpLexer.RBRKT .AND. ! EoS() 
               tokens:Add(ConsumeAndGet())
            ENDDO
            IF La1 == XSharpLexer.RBRKT
               tokens:Add(ConsumeAndGet())
            ENDIF
         ENDDO
         RETURN tokens
         
      PRIVATE METHOD ParseVisibilityAndModifiers() AS   Modifiers
         VAR result := Modifiers.None
         DO WHILE ! EoS()
            VAR done := FALSE
            SWITCH la1
               // Visibility
            CASE XSharpLexer.PUBLIC
               result |= Modifiers.Public   
            CASE XSharpLexer.EXPORT
               result |= Modifiers.Public   
            CASE XSharpLexer.HIDDEN
               result |= Modifiers.Private
            CASE XSharpLexer.PRIVATE
               result |= Modifiers.Private
            CASE XSharpLexer.PROTECTED
               result |= Modifiers.Protected
            CASE XSharpLexer.INTERNAL
               result |= Modifiers.Internal
            // Real modifiers
                  
            CASE XSharpLexer.ABSTRACT
               result |= Modifiers.Abstract
            CASE XSharpLexer.EXTERN
                  result |= Modifiers.External
                  
            CASE XSharpLexer.UNSAFE
               result |= Modifiers.Unsafe
            CASE XSharpLexer.STATIC
               result |= Modifiers.Static
            CASE XSharpLexer.PARTIAL
               result |= Modifiers.Partial
            CASE XSharpLexer.NEW
               result |= Modifiers.New
            CASE XSharpLexer.OVERRIDE
               result |= Modifiers.Override
            CASE XSharpLexer.VIRTUAL
               result |= Modifiers.Virtual
            CASE XSharpLexer.SEALED
               result |= Modifiers.Sealed
            CASE XSharpLexer.CONST
               result |= Modifiers.Const
            CASE XSharpLexer.INSTANCE
                  result |= Modifiers.Instance
               result |= Modifiers.Protected
            CASE XSharpLexer.INITONLY
               result |= Modifiers.InitOnly
            OTHERWISE
               done := TRUE
            END SWITCH
            IF ! done
               Consume()
            ELSE
               EXIT
            ENDIF
         ENDDO
         RETURN result
         
         
      PRIVATE METHOD IsStartOfEntity(entityKind OUT Kind, mods AS Modifiers) AS LOGIC
         entityKind := Kind.Unknown
         SWITCH La1
         CASE XSharpLexer.BEGIN
               // namespace ?
            IF La2 == XSharpLexer.NAMESPACE
               entityKind := Kind.Namespace
            ENDIF
         CASE XSharpLexer.CLASS
            entityKind := Kind.Class
         CASE XSharpLexer.STRUCTURE
            entityKind := Kind.Structure
         CASE XSharpLexer.DELEGATE
            entityKind := Kind.Delegate
         CASE XSharpLexer.INTERFACE
            entityKind := Kind.Interface
         CASE XSharpLexer.ENUM
            entityKind := Kind.Enum
         CASE XSharpLexer.EVENT
            entityKind := Kind.Event
         CASE XSharpLexer.METHOD
            entityKind := Kind.Method
         CASE XSharpLexer.ACCESS
            entityKind := Kind.Access
         CASE XSharpLexer.ASSIGN
            entityKind := Kind.Assign
         CASE XSharpLexer.PROPERTY
            entityKind := Kind.Property
         CASE XSharpLexer.OPERATOR
            entityKind := Kind.Operator
         CASE XSharpLexer.CONSTRUCTOR
            entityKind := Kind.Constructor
         CASE XSharpLexer.DESTRUCTOR
            entityKind := Kind.Destructor
         CASE XSharpLexer.DECLARE
               // access, assign, method
            entityKind := Kind.Ignore
         CASE XSharpLexer.DEFINE
               // define class ?
            IF La2 == XSharpLexer.CLASS
               entityKind := Kind.Class
            ELSEIF SELF:IsId(La2)
               entityKind := Kind.VODefine
            ENDIF
         CASE XSharpLexer.VOSTRUCT
            entityKind := Kind.VOStruct
         CASE XSharpLexer.UNION
            entityKind := Kind.Union
         CASE XSharpLexer.MEMBER
            entityKind := Kind.EnumMember
         CASE XSharpLexer.FIELD
            // field declaration only inside FoxPro class definition
         CASE XSharpLexer.ADD
            // Todo handle Add Object clause inside Class.
            entityKind := Kind.Unknown
         CASE XSharpLexer.FUNCTION
            entityKind := Kind.Function
         CASE XSharpLexer.PROCEDURE
            entityKind := Kind.Procedure
         CASE XSharpLexer.GLOBAL
            entityKind := Kind.VOGlobal
         CASE XSharpLexer.DLL
            IF La2 == XSharpLexer.FUNCTION .OR. La2 == XSharpLexer.PROCEDURE
               entityKind := Kind.VODLL
            ENDIF
         OTHERWISE
            IF IsId(La1) .AND. mods != Modifiers.None
               LOCAL parent AS XType
               IF CurrentEntity IS XType 
                  parent := (XType) CurrentEntity
               ELSEIF CurrentEntity != NULL .AND. CurrentEntity:Parent IS XType 
                  parent := (XType) CurrentEntity:Parent 
               ENDIF
               IF ! XType.IsGlobalType(parent) 
                  entityKind := Kind.Field
               ENDIF
            ENDIF               
         END SWITCH
         
         RETURN entityKind != Kind.Unknown
         
         
      PRIVATE METHOD ParseBlock() AS LOGIC
         // Adds, updates or removes block token on the block tokens stack
         // Start of block is also added to the _BlockList
         LOCAL nStart  := 0 AS LONG
         LOCAL nMiddle := 0 AS LONG
         LOCAL nEnd    := 0 AS LONG
         SWITCH La1
         CASE XSharpLexer.BEGIN
            SWITCH La2
            // tokens in the same order as the rules inside xsharp.g4                    
            CASE XSharpLexer.SEQUENCE
            CASE XSharpLexer.LOCK
            CASE XSharpLexer.SCOPE
            CASE XSharpLexer.SWITCH
            CASE XSharpLexer.USING
            CASE XSharpLexer.UNSAFE
            CASE XSharpLexer.CHECKED
            CASE XSharpLexer.UNCHECKED
            CASE XSharpLexer.FIXED
               nStart := 2
            END SWITCH
            
         CASE XSharpLexer.DO
            SWITCH La2
               CASE XSharpLexer.WHILE
               CASE XSharpLexer.CASE
            CASE XSharpLexer.SWITCH
               nStart := 2
            END SWITCH
            
            CASE XSharpLexer.IF
            CASE XSharpLexer.FOR
            CASE XSharpLexer.FOREACH
            CASE XSharpLexer.REPEAT
            CASE XSharpLexer.TRY
            CASE XSharpLexer.WITH
            CASE XSharpLexer.TEXT
            CASE XSharpLexer.SWITCH  
            CASE XSharpLexer.GET  
            CASE XSharpLexer.SET  
            CASE XSharpLexer.ADD  
            CASE XSharpLexer.REMOVE  
               nStart := 1
            // Middle of a block                    
         CASE XSharpLexer.CASE
         CASE XSharpLexer.OTHERWISE
         CASE XSharpLexer.ELSEIF
         CASE XSharpLexer.ELSE
         CASE XSharpLexer.CATCH
         CASE XSharpLexer.FINALLY
            nMiddle := 1
         CASE XSharpLexer.RECOVER 
            IF La2 == XSharpLexer.USING
               nMiddle := 2
            ENDIF
            // End of a block
         CASE XSharpLexer.ENDCASE
         CASE XSharpLexer.ENDDO
         CASE XSharpLexer.ENDIF
         CASE XSharpLexer.NEXT
         CASE XSharpLexer.UNTIL
            nEnd := 1
         CASE XSharpLexer.END
               SWITCH La2
               // tokens in the same order as the rules inside xsharp.g4                    
               CASE XSharpLexer.SEQUENCE
               CASE XSharpLexer.LOCK
               CASE XSharpLexer.SCOPE
               CASE XSharpLexer.SWITCH
               CASE XSharpLexer.USING
               CASE XSharpLexer.UNSAFE
               CASE XSharpLexer.CHECKED
               CASE XSharpLexer.UNCHECKED
               CASE XSharpLexer.FIXED
               CASE XSharpLexer.TRY
               CASE XSharpLexer.WITH
               
               CASE XSharpLexer.GET        // Accessors
               CASE XSharpLexer.SET  
               CASE XSharpLexer.ADD  
               CASE XSharpLexer.REMOVE  
                     nEnd := 2
                     
               CASE XSharpLexer.EOS        // End without following keyword is usually also allowed
                  nEnd := 1
            END SWITCH
         END SWITCH
         IF nStart > 0
            IF SELF:_collectBlocks
               VAR block := XBlock{ Lt1, IIF(nStart == 1, Lt1, Lt2)}
               _BlockList:Add(block)
               _BlockStack:Push(block)
            ENDIF
            IF SELF:_collectLocals
              IF SELF:La1 == XSharpLexer.SET .OR. SELF:La1 == XSharpLexer.REMOVE .OR. SELF:La1 == XSharpLexer.ADD
                  VAR id := "Value"
                  VAR strType := SELF:CurrentEntity:TypeName
                  VAR start := SELF:Lt1
                  VAR @@end   := SELF:Lt2
                  VAR range    := TextRange{start, @@end}
                  VAR interval := TextInterval{start, @@end}
                  VAR xVar := XVariable{SELF:CurrentEntity, id, Kind.Local, range, interval, strType} 
                  SELF:_locals:Add(xVar)
               ENDIF
                
               VAR tokens := List<IToken>{}
               DO WHILE ! Eos()
                  IF SELF:Matches(XSharpLexer.IMPLIED, XSharpLexer.VAR)
                     IF SELF:IsId(La2)
                        VAR start := lt2
                        Consume()      // IMPLIED or VAR
                        VAR id    := SELF:ParseIdentifier()
                        LOCAL expr AS IList<IToken>
                        IF SELF:IsAssignOp(La1) .OR. SELF:La1 == XSharpLexer.IN
                           IF (SELF:La1 != XSharpLexer.IN)
                              Consume()   // := 
                           ENDIF
                           expr := SELF:ParseExpressionAsTokens()
                        ENDIF
                        VAR range    := TextRange{start, lastToken}
                        VAR interval := TextInterval{start, lastToken}
                        VAR xVar := XVariable{SELF:CurrentEntity, id, Kind.Local, range, interval, XElement.VarType } {Expression := expr }
                        SELF:_locals:Add(xVar)
                     ENDIF
                  ENDIF
                  Consume()
               ENDDO
               
            ENDIF
            SELF:ReadLine()
            RETURN TRUE
         ENDIF
         IF nMiddle > 0
            // Do something
            IF SELF:_collectBlocks .AND. _BlockStack:Count > 0
               CurrentBlock:Children:Add( XBlock{Lt1,IIF(nMiddle == 1, Lt1, Lt2)})
            ENDIF
            IF La1 == XSharpLexer.CATCH
               IF SELF:IsId(La2) 
                  Consume()
                  VAR start   := Lt1
                  VAR id      := ParseIdentifier()
                  VAR strType := "System.Exception"
                  IF La1 == XSharpLexer.AS
                      strType := SELF:ParseAsIsType()
                  ENDIF
                  VAR range    := TextRange{start, lastToken}
                  VAR interval := TextInterval{start, lastToken}
                  VAR xVar := XVariable{SELF:CurrentEntity, id, Kind.Local, range, interval, strType} 
                  SELF:_locals:Add(xVar)
               ENDIF
            ENDIF
            SELF:ReadLine()
            RETURN TRUE
         ENDIF
         IF nEnd > 0
            IF SELF:_collectBlocks .AND. _BlockStack:Count > 0
               CurrentBlock:Children:Add( XBlock{Lt1,IIF(nEnd == 1, Lt1, Lt2)})
               _BlockStack:Pop()
            ENDIF
            SELF:ReadLine()
            RETURN TRUE
         ENDIF
         RETURN FALSE
         
         
      PRIVATE METHOD IsEndOfEntity(EntityKind OUT Kind) AS LOGIC
         IF La1 == XSHarpLexer.END
            SWITCH La2
               // mandatory END <keyword> pairs
            CASE XSharpLexer.NAMESPACE
                  EntityKind := Kind.Namespace
               RETURN TRUE
            CASE XSharpLexer.CLASS
                  EntityKind := Kind.Class
               RETURN TRUE
            CASE XSharpLexer.STRUCTURE
                  EntityKind := Kind.Structure
               RETURN TRUE
            CASE XSharpLexer.ENUM
                  EntityKind := Kind.Enum
                  RETURN TRUE
               
            CASE XSharpLexer.INTERFACE
                  EntityKind := Kind.Interface
                  RETURN TRUE
               
            CASE XSharpLexer.PROPERTY
                  EntityKind := Kind.Property
                  RETURN TRUE
               
            CASE XSharpLexer.EVENT
                  EntityKind := Kind.Event
                  RETURN TRUE
                  
                  // Optional
               
            CASE XSharpLexer.METHOD
                  EntityKind := Kind.Method
                  RETURN TRUE
               
            CASE XSharpLexer.ACCESS
                  EntityKind := Kind.Access
                  RETURN TRUE
               
            CASE XSharpLexer.ASSIGN
                  EntityKind := Kind.Assign
                  RETURN TRUE
               
            CASE XSharpLexer.OPERATOR
                  EntityKind := Kind.Operator
                  RETURN TRUE
               
            CASE XSharpLexer.CONSTRUCTOR
                  EntityKind := Kind.Constructor
                  RETURN TRUE
               
            CASE XSharpLexer.DESTRUCTOR
                  EntityKind := Kind.Destructor
                  RETURN TRUE
               
            CASE XSharpLexer.FUNCTION
                  EntityKind := Kind.Function
                  RETURN TRUE
               
            CASE XSharpLexer.PROCEDURE
                  EntityKind := Kind.Procedure
                  RETURN TRUE
               
            CASE XSharpLexer.VOSTRUCT
                  EntityKind := Kind.VoStruct
                  RETURN TRUE
               
            CASE XSharpLexer.UNION
                  EntityKind := Kind.Union
                  RETURN TRUE
                  
               // END <nothing> is NOT allowed for entities since that conflicts with the END for blocks
            END SWITCH
         ENDIF                
         EntityKind := Kind.Unknown
         RETURN FALSE
         
         
         
         
         #region GetTokens
      PRIVATE METHOD La(nToken AS LONG) AS LONG
         nToken += _index-1
         IF (nToken < _input:Count)
            VAR t := _input[nToken]
            RETURN t:Type
         ENDIF
         RETURN XSharpLexer.Eof
         
      PRIVATE METHOD Lt(nToken AS LONG) AS IToken
         nToken += _index-1
         IF (nToken < _input:Count)
            RETURN _input[nToken]
         ENDIF
         RETURN NULL
         
      PRIVATE METHOD Eoi() AS LOGIC
         RETURN _index >= _input:Count
         
      PRIVATE METHOD Eos() AS LOGIC
         RETURN La1 == XSharpLexer.EOS .OR. Eoi()
         
      PRIVATE METHOD SaveLastToken() AS VOID
         IF ! SELF:Eoi() .AND. La1 != XSharpLexer.EOS
            _lastToken := _input[_index]
         ENDIF
         
         
      PRIVATE METHOD PushBack() AS VOID
         _index-= 1
         RETURN
         
      PRIVATE METHOD Consume() AS VOID
         SELF:SaveLastToken()
         _index+= 1
         RETURN
         
      PRIVATE METHOD ConsumeAndGet() AS IToken
         VAR t := _input[_index]
         _lastToken := t
         _index+= 1
         RETURN t
         
      PRIVATE METHOD ConsumeAndGetText() AS STRING
         VAR t := _input[_index]
         _lastToken := t
         _index+= 1
         RETURN t:GetText()
         
      PRIVATE METHOD Matches(nTypes PARAMS LONG[]) AS LOGIC
         IF nTypes:Contains(La1)
            RETURN TRUE
         ENDIF
         RETURN FALSE
         
      PRIVATE METHOD ConsumeAndGetAny(nTypes PARAMS LONG[]) AS IToken
         IF nTypes:Contains(La1)
            RETURN ConsumeAndGet()
         ENDIF
         RETURN NULL
         
         
         
      PRIVATE METHOD Expect(nType AS LONG) AS LOGIC
         IF La1 == nType
            Consume()
            RETURN TRUE
         ENDIF
         RETURN FALSE
         
      PRIVATE METHOD ExpectAny(nTypes PARAMS LONG[]) AS LOGIC
         IF nTypes:Contains(La1)
            Consume()
            RETURN TRUE
         ENDIF
         RETURN FALSE
         
      PRIVATE METHOD ExpectAndGet(nType AS LONG, t OUT IToken) AS LOGIC
         IF La1 == nType
            t := ConsumeAndGet()
            RETURN TRUE
         ENDIF
         t := NULL
         RETURN FALSE
         
         
      PRIVATE METHOD ReadLine() AS VOID
         DO WHILE ! Eos()
            Consume()
         ENDDO
         DO WHILE La1 == XSharpLexer.EOS
            Consume() // Consume the EOS
         ENDDO
         RETURN
         #endregion
      
      PRIVATE METHOD IsId(token AS LONG) AS LOGIC
         IF token == XSharpLexer.ID .OR. token == XSharpLexer.KWID
            RETURN TRUE
         ENDIF
         // Soft keywords need to be 
         RETURN SELF:IsKeywordXs(token) .OR. SELF:IsKeywordFox(token) .OR. SELF:IsKeywordXpp(token)
         
         
      PRIVATE METHOD ParseIdentifier() AS STRING
         IF SELF:IsId(La1)
            IF La1 == XSharpLexer.KWID
               RETURN SELF:ConsumeAndGetText():Substring(2)
            ELSE
               RETURN SELF:ConsumeAndGetText()
            ENDIF
         ENDIF
         RETURN ""
         
         
      PRIVATE METHOD ParseOptionalClassClause() AS STRING
         IF La1 == XSharpLexer.CLASS
            SELF:Consume()
            RETURN SELF:ParseQualifiedName()
         ENDIF
         RETURN ""
         
         
      PRIVATE METHOD ParseQualifiedName() AS STRING
         LOCAL result := "" AS STRING
         VAR Tokens := List<IToken>{}
         IF La1 == XSharpLexer.ID .OR. La1 == XSharpLexer.KWID
            Tokens:Add(ConsumeAndGet())
            DO WHILE La1 == XSharpLexer.DOT .AND.  SELF:IsId(La2)
               Tokens:Add(SELF:ConsumeAndGet())
               Tokens:Add(SELF:ConsumeAndGet())
            ENDDO
         ENDIF
         RETURN TokensAsString(tokens)
         
      PRIVATE METHOD TokensAsString(tokens AS IList<IToken>) AS STRING
         LOCAL sb AS StringBuilder
         LOCAL last := NULL AS IToken
         sb := StringBuilder{}
         
         FOREACH VAR t IN tokens
            IF last != NULL
               IF t:StartIndex > last:StopIndex +1
                  sb:Append(" ")
               ENDIF
            ENDIF
            sb:Append(t:GetText())
            last := t
         NEXT
         RETURN sb:ToString()
         
      PRIVATE METHOD ParseEntity(entityKind AS Kind) AS IList<XElement>
         LOCAL result AS IList<XElement>
         SWITCH entityKind
         CASE Kind.Ignore
            ReadLine()
         CASE Kind.NameSpace
            result := ParseNameSpace()                 
         CASE Kind.Class
            result := ParseTypeDef()                    
         CASE Kind.Structure
            result := ParseTypeDef()                    
         CASE Kind.Interface
            result := ParseTypeDef()                    
         CASE Kind.Delegate
            result := ParseDelegate()
         CASE Kind.Access
            result := ParseMethod()
         CASE Kind.Assign
            result := ParseMethod()
         CASE Kind.Method
            result := ParseMethod()
         CASE Kind.Function
            result := ParseFuncProc()
         CASE Kind.Procedure
            result := ParseFuncProc()
         CASE Kind.VODLL
            result := ParseVODLL()                        
         CASE Kind.VOStruct
            result := ParseVOStruct()
         CASE Kind.Union
            result := ParseVOUnion()
         CASE Kind.Enum
            result := ParseEnum()
         CASE Kind.EnumMember
            IF SELF:CurrentEntity:Kind == Kind.Enum
               result := ParseEnumMember()
            ELSE
               result := ParseVoStructMember()
            ENDIF                    
         CASE Kind.VODefine
            result := ParseVODefine()
         CASE Kind.VOGlobal
            result := ParseVOGlobals()
         CASE Kind.Property
            result := ParseProperty()
               
         CASE Kind.Event
            result := ParseEvent()
            
         CASE Kind.Operator
            result := ParseOperator()
            
         CASE Kind.Constructor
            result := ParseConstructor()
               
         CASE Kind.Destructor
            result := ParseDestructor()
            
         CASE Kind.Field
            result := ParseClassVars()   
         END SWITCH            
         RETURN result
         
         #region Main entities
         
         PRIVATE METHOD ParseFuncProc() AS IList<XElement>
/*
funcproc      : (Attributes=attributes)? (Modifiers=funcprocModifiers)?   
              T=(FUNCTION|PROCEDURE) Sig=signature
              InitExit=(INIT1|INIT2|INIT3|EXIT)?                        
              vodummyclauses
              end=eos   
              StmtBlk=statementBlock
              (END T2=(FUNCTION|PROCEDURE)   EOS )?
              ;
*/
         LOCAL kind AS Kind 
         IF SELF:La1 == XSharpLexer.FUNCTION 
            kind := Kind.Function
         ELSEIF SELF:La1 == XSharpLexer.PROCEDURE
            kind := Kind.Procedure
         ELSE
            RETURN NULL
         ENDIF
         Consume()
            VAR sig := SELF:ParseSignature()
            
            VAR initexit := ""
            IF SELF:Matches(XSharpLexer.INIT1,XSharpLexer.INIT2,XSharpLexer.INIT3,XSharpLexer.EXIT)
               initexit := SELF:ConsumeAndGetText()
            ENDIF
            VAR range    := textRange{_start, lastToken}
            VAR interval := textInterVal{_start, lastToken} 
            readLine()
            
            VAR xmember := XTypeMember{sig:Id, kind, _mods, _vis, range, interval,sig:DataType, _mods:HasFlag(Modifiers.Static)}
            xmember:File := SELF:_file
            SELF:CopySignatureValues(xmember, sig)
            RETURN List<XElement>{} {xmember}        
            
         PRIVATE METHOD ParseNamespace() AS IList<XElement>
/*
namespace_          : BEGIN NAMESPACE Name=name e=eos
                      (Entities+=entity)*
                      END NAMESPACE EOS
                    ;
*/         
            IF SELF:la1 != XSharpLexer.BEGIN .AND. SELF:La2 != XSharpLexer.NAMESPACE
               RETURN NULL
            ENDIF
            Consume()   // BEGIN
            Consume()   // NAMESPACE 
            VAR id := ParseQualifiedName()
            VAR range    := textRange{_start, lastToken}
            VAR interval := textInterVal{_start, lastToken} 
            readLine()
            VAR xtype := XType{id, Kind.Namespace, _mods, _vis, range, interval,_file}
            RETURN List<XElement>{} {xtype}        
            
         PRIVATE METHOD ParseTypeDef() AS IList<XElement>
/*
interface_          : (Attributes=attributes)? (Modifiers=classModifiers)?            
                      I=INTERFACE (Namespace=nameDot)? Id=identifier                        
                      TypeParameters=typeparameters?                                      // TypeParameters indicate Generic Interface
                      ((INHERIT|COLON) Parents+=datatype)? (COMMA Parents+=datatype)*
                      (ConstraintsClauses+=typeparameterconstraintsclause)*              // Optional typeparameterconstraints for Generic Interface
                      e=eos
                      (Members+=classmember)*
                      END INTERFACE EOS
                    ;
class_              : (Attributes=attributes)? (Modifiers=classModifiers)?              
                      C=CLASS (Namespace=nameDot)? Id=identifier                          
                      TypeParameters=typeparameters?                                    // TypeParameters indicate Generic Class
                      (INHERIT BaseType=datatype)?                                  
                      (IMPLEMENTS Implements+=datatype (COMMA Implements+=datatype)*)?
                      (ConstraintsClauses+=typeparameterconstraintsclause)*             // Optional typeparameterconstraints for Generic Class
                      e=eos
                      (Members+=classmember)*
                      END CLASS EOS
                    ;
structure_          : (Attributes=attributes)? (Modifiers=classModifiers)?
                      S=STRUCTURE (Namespace=nameDot)? Id=identifier
                      TypeParameters=typeparameters?
                      (IMPLEMENTS Implements+=datatype (COMMA Implements+=datatype)*)?
                      (ConstraintsClauses+=typeparameterconstraintsclause)* e=eos
                      (Members+=classmember)*
                      END STRUCTURE EOS
                    ;
                    

*/            
            LOCAL kind AS Kind
            SWITCH SELF:La1
            CASE XSharpLexer.CLASS
               kind := Kind.Class
            CASE XSharpLexer.INTERFACE
               kind := Kind.Interface
            CASE XSharpLexer.STRUCTURE
               kind := Kind.Structure
            OTHERWISE
               RETURN NULL
            END SWITCH
            Consume()

            LOCAL constraints   AS List<STRING>
            LOCAL parentType    AS STRING
            LOCAL interfaces    AS List<STRING>
            // read Id with optional namespace prefix
            VAR id := ParseQualifiedName()
            VAR typePars := SELF:ParseTypeParameters()
            // get inherit clause
            IF La1 == XSharpLexer.INHERIT .OR. La1 == XSharpLexer.COLON
               Consume()
               parentType := ParseTypeName()
            ENDIF
            // get implements clause + list of interfaces
            IF La1 == XSharpLexer.IMPLEMENTS
               interfaces := List<STRING>{}
               DO WHILE La1 == XSharpLexer.IMPLEMENTS .OR. La1 == XSharpLexer.COMMA
                  Consume()
                  interfaces:Add(parseTypeName())
               ENDDO
            ENDIF
            DO WHILE La1 == XSharpLexer.WHERE
               IF constraints == NULL
                  constraints := List<STRING>{}
               ENDIF
               constraints:Add(SELF:ParseTypeParameterConstraints())
            ENDDO
            // read to EndOfLine
            VAR range    := textRange{_start, lastToken}
            VAR interval := textInterVal{_start, lastToken} 
            readLine()
            
            VAR xType := XType{id, kind, _mods, _vis, range, interval, _file}
            IF interfaces?:Count > 0
               FOREACH VAR sInterface IN interfaces
                  xType:AddInterface(sInterface)
               NEXT
            ENDIF
            IF ! String.IsNullOrEmpty(parentType)
               xType:ParentName := parentType
            ENDIF
            xType:IsPartial := _mods:HasFlag(Modifiers.Partial)
            IF constraints?:Count > 0
               FOREACH VAR constraint IN constraints
                  xType:AddConstraints(constraint)
               NEXT
            ENDIF
            IF typePars?:Count > 0
               FOREACH VAR typepar IN typePars
                  xType:AddTypeParameter(typepar)
               NEXT
            ENDIF
            RETURN List<XElement>{} {xType}
            
            
         PRIVATE METHOD ParseDelegate() AS IList<XElement>
/*
delegate_           : (Attributes=attributes)? (Modifiers=classModifiers)?
                      D=DELEGATE (Namespace=nameDot)? Id=identifier
                      TypeParameters=typeparameters?
                      ParamList=parameterList?
                      (AS Type=datatype)?
                      (ConstraintsClauses+=typeparameterconstraintsclause)*
                      e=EOS
                    ;


*/           
            IF SELF:La1 == XSharpLexer.DELEGATE
               Consume()
            ELSE
               RETURN NULL
            ENDIF

            VAR sig      := SELF:ParseSignature()
            VAR range    := textRange{_start, lastToken}
            VAR interval := textInterVal{_start, lastToken} 
            VAR xtype    := XType{sig:Id, Kind.Delegate, _mods, _vis, range, interval,_file}{SingleLine := TRUE}
            VAR xmember  := XTypeMember{sig:Id, Kind.Delegate, _mods, _vis, ;
                              range, interval,sig:DataType, _mods:HasFlag(Modifiers.Static)} {SingleLine := TRUE}
                              xtype:AddMember(xmember)
            xmember:File := SELF:_file                              
            SELF:CopySignatureValues(xmember, sig)
            RETURN List<XElement>{} {xtype}
            #endregion
            
         #region ClassMembers
      PRIVATE METHOD ParseMethod(  ) AS IList<XElement>
/*
// method rule used inside and outside class members rule 
method              : (Attributes=attributes)? (Modifiers=memberModifiers)?
                      T=methodtype (ExplicitIface=nameDot)? Sig=signature
                      (CLASS (Namespace=nameDot)? ClassId=identifier)?      // Class Clause needed when entity and allowed when class member
                      vodummyclauses
                      end=eos
                      StmtBlk=statementBlock
                      (END T2=methodtype EOS)?
                    ;

methodtype          : Token=(METHOD | ACCESS | ASSIGN )
                    ;

*/         
         LOCAL kind AS Kind 
         IF SELF:La1 == XSharpLexer.ACCESS 
            kind := Kind.Access
         ELSEIF SELF:La1 == XSharpLexer.ASSIGN
            kind := Kind.Assign
         ELSEIF SELF:La1 == XSharpLexer.METHOD
            kind := Kind.Method
         ELSE
            RETURN NULL
         ENDIF
         Consume()
         
         VAR sig := SELF:ParseSignature()
         VAR classClause := ParseOptionalClassClause()
         // read to EndOfLine
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         
         VAR xmember := XTypeMember{sig:Id, kind, _mods, _vis, range, interval,sig:DataType, _mods:HasFlag(Modifiers.Static)}
         xmember:File := SELF:_file
         SELF:CopySignatureValues(xmember, sig)
         
         RETURN List<XElement>{} {xmember}
         
      PRIVATE METHOD ParseProperty() AS IList<XElement>
            IF SELF:La1 == XSharpLexer.PROPERTY
               Consume()
            ELSE
               RETURN NULL
            ENDIF
         // Note that inside the editor the SET and GET accessors are parsed as blocks and not as entities
/*
property            : (Attributes=attributes)? (Modifiers=memberModifiers)?
                      P=PROPERTY (SELF ParamList=propertyParameterList | (ExplicitIface=nameDot)? Id=identifier)
                      (ParamList=propertyParameterList)?
                      (AS Type=datatype)?
                      ( Auto=AUTO (AutoAccessors+=propertyAutoAccessor)* (Op=assignoperator Initializer=expression)? end=EOS	// Auto
                        | (LineAccessors+=propertyLineAccessor)+ end=EOS													// Single Line
                        | Multi=eos (Accessors+=propertyAccessor)+  END PROPERTY? EOS				// Multi Line
                      )
                    ;

propertyParameterList
                    : LBRKT  (Params+=parameter (COMMA Params+=parameter)*)? RBRKT
                    | LPAREN (Params+=parameter (COMMA Params+=parameter)*)? RPAREN		// Allow Parentheses as well
                    ;

propertyAutoAccessor: Attributes=attributes? Modifiers=accessorModifiers? Key=(GET|SET)
                    ;

propertyLineAccessor: Attributes=attributes? Modifiers=accessorModifiers?
                      ( {InputStream.La(2) != SET}? Key=GET Expr=expression?
                      | {InputStream.La(2) != GET}? Key=SET ExprList=expressionList?
                      | Key=(GET|SET) )
                    ;
expressionList	    : Exprs+=expression (COMMA Exprs+=expression)*
                    ;

propertyAccessor    : Attributes=attributes? Modifiers=accessorModifiers?
                      ( Key=GET end=eos StmtBlk=statementBlock END GET?
                      | Key=SET end=eos StmtBlk=statementBlock END SET? )
                      end=eos
                    ;
                    
*/         
         VAR id := ""
         IF SELF:Matches(XSharpLexer.SELF)   // Self property
            id := ConsumeAndGetText()
         ELSE
            id := ParseQualifiedName()
         ENDIF
         VAR aParams := List<XVariable>{}
         IF Matches(XSharpLexer.LPAREN)
            aParams := ParseParameterList()
         ELSEIF Matches(XSharpLexer.LBRKT)
            aParams := ParseParameterList(TRUE)
         ENDIF
         VAR sType := ParseAsIsType()
         LOCAL lSingleLine AS LOGIC
         DO WHILE ! Eos()
            IF Matches(XSharpLexer.AUTO, XSharpLexer.GET,XSharpLexer.SET)
               lSingleLine := TRUE
            ENDIF
            Consume()
         ENDDO
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xmember := XTypeMember{id, Kind.Property, _mods, _vis, range, interval,sType} {SingleLine := lSingleLine}
         xmember:File := SELF:_file
         xmember:AddParameters(aParams)
         RETURN List<XElement>{} {xmember}
         
      PRIVATE METHOD ParseEvent() AS IList<XElement>
            IF SELF:La1 == XSharpLexer.EVENT
               Consume()
            ELSE
               RETURN NULL
            ENDIF
      
         // Inside the editor the ADD and REMOVE accessors are parsed as blocks and not as entities
/*
event_              : (Attributes=attributes)? (Modifiers=memberModifiers)?
                       E=EVENT (ExplicitIface=nameDot)? Id=identifier (AS Type=datatype)?
                       ( end=EOS
                        | (LineAccessors += eventLineAccessor)+ end=EOS
                        | Multi=eos (Accessors+=eventAccessor)+ END EVENT? EOS
                       )
                    ;

eventLineAccessor   : Attributes=attributes? Modifiers=accessorModifiers?
                      ( {InputStream.La(2) != REMOVE}? Key=ADD ExprList=expressionList?
                      | {InputStream.La(2) != ADD}?    Key=REMOVE ExprList=expressionList?
                      | Key=(ADD|REMOVE) )
                    ;
eventAccessor       : Attributes=attributes? Modifiers=accessorModifiers?
                      ( Key=ADD     end=eos StmtBlk=statementBlock END ADD?
                      | Key=REMOVE  end=eos StmtBlk=statementBlock END REMOVE? )
                      end=eos
                    ;                    
*/         
         VAR id := ParseQualifiedName()
         VAR strType  := ParseAsIsType()
         LOCAL lSingleLine AS LOGIC
         DO WHILE ! Eos()
            IF Matches( XSharpLexer.ADD,XSharpLexer.REMOVE)
               lSingleLine := TRUE
            ENDIF
            Consume()
         ENDDO
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xmember := XTypeMember{id, Kind.Event, _mods, _vis, range, interval,strType}  {SingleLine := lSingleLine}
         xmember:File := SELF:_file
         RETURN List<XElement>{} {xmember}
         
      PRIVATE METHOD ParseOperator() AS IList<XElement>
            IF SELF:La1 == XSharpLexer.OPERATOR
               Consume()
            ELSE
               RETURN NULL
            ENDIF
      
/*
overloadedOps       : Token= (PLUS | MINUS | NOT | TILDE | INC | DEC | TRUE_CONST | FALSE_CONST |
                              MULT | DIV | MOD | AMP | PIPE | LSHIFT | RSHIFT | EEQ | NEQ | NEQ2 |
                              GT | LT | GTE | LTE |
                              AND | OR )  // these two do not exist in C# and are mapped to & and |
                    ;

conversionOps		: Token=( IMPLICIT | EXPLICIT )
                    ;

operator_           : Attributes=attributes? Modifiers=operatorModifiers?
                      o1=OPERATOR (Operation=overloadedOps | Conversion=conversionOps) Gt=GT?
                      ParamList=parameterList
                      (AS Type=datatype)?
                      end=eos
                      StmtBlk=statementBlock
                     (END o1=OPERATOR EOS)?
                    ;

*/         
         LOCAL t1 AS IToken
         LOCAL t2 AS IToken 
         STATIC LOCAL operatortokens := <LONG> {XSharpLexer.PLUS , XSharpLexer.MINUS , XSharpLexer.NOT , XSharpLexer.TILDE , XSharpLexer.INC, ;
            XSharpLexer.DEC ,XSharpLexer.TRUE_CONST ,XSharpLexer.FALSE_CONST , XSharpLexer.MULT , ;
            XSharpLexer.DIV ,XSharpLexer.MOD ,XSharpLexer.AMP ,XSharpLexer.PIPE ,XSharpLexer.LSHIFT ,XSharpLexer.RSHIFT, ;
            XSharpLexer.EEQ , XSharpLexer.NEQ , XSharpLexer.NEQ2 ,XSharpLexer.GT , XSharpLexer.LT ,;
            XSharpLexer.GTE , XSharpLexer.LTE , XSharpLexer.AND , XSharpLexer.OR, XSharpLexer.IMPLICIT, XSharpLexer.EXPLICIT}  AS LONG[]
         IF Matches(operatortokens)
            t1 := SELF:ConsumeAndGet()
         ENDIF
         IF Matches (XSharpLexer.GT)
            t2 := SELF:ConsumeAndGet()
         ENDIF
         VAR aParams     := SELF:ParseParameterList()
         VAR sType       := SELF:ParseAsIsType()
         
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         
         VAR id := t1:GetText()+ IIF(t2 != NULL, t2:GetText(),"")
         readLine()
         VAR xmember := XTypeMember{id, Kind.Operator, _mods, _vis, range, interval,sType}
         xmember:File := SELF:_file
         xmember:AddParameters(aParams)
         RETURN List<XElement>{} {xmember}
         
         
      PRIVATE METHOD ParseConstructor() AS IList<XElement>
      
/*constructor         :  (Attributes=attributes)? (Modifiers=constructorModifiers)?
                      c1=CONSTRUCTOR (ParamList=parameterList)? (AS VOID)? // As Void is allowed but ignored
                        (CallingConvention=callingconvention)? 
                        (CLASS (Namespace=nameDot)? ClassId=identifier)?		
                        end=eos
                      (Chain=constructorchain)?
                      StmtBlk=statementBlock
                      (END c2=CONSTRUCTOR EOS)?
                    ;
*/         
         IF SELF:La1 == XSharpLexer.CONSTRUCTOR
            Consume()
         ELSE
            RETURN NULL
         ENDIF
         VAR id  := ".ctor"
         VAR aParams     := SELF:ParseParameterList()
         VAR asType      := SELF:ParseAsisType()
         VAR callconv    := SELF:ParseCallingConvention()
         VAR classClause := SELF:ParseOptionalClassClause()
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xmember := XTypeMember{id, Kind.Constructor, _mods, _vis,range, interval,""}
         xmember:File := SELF:_file
         xmember:AddParameters(aParams)
         RETURN List<XElement>{} {xmember}
         
      PRIVATE METHOD ParseDestructor() AS IList<XElement>
/*
destructor          : (Attributes=attributes)? (Modifiers=destructorModifiers)?
                      d1=DESTRUCTOR (LPAREN RPAREN)? 
                      (CLASS (Namespace=nameDot)? ClassId=identifier)?
                      end=eos
                      StmtBlk=statementBlock
                      (END d2=DESTRUCTOR EOS)?
                    ;

*/         
         IF SELF:La1 == XSharpLexer.DESTRUCTOR
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         VAR id  := ".dtor"
         IF La1 == XSharpLexer.LPAREN .AND. La2 == XSharpLexer.RPAREN
            Consume()
            Consume()
         ENDIF
         VAR classClause := SELF:ParseOptionalClassClause()
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xmember := XTypeMember{id, Kind.Destructor, _mods, _vis, range, interval,"VOID"}
         xmember:File := SELF:_file
         RETURN List<XElement>{} {xmember}
         
      PRIVATE METHOD ParseClassVars() AS IList<XElement>
/*
classvars           : (Attributes=attributes)? (Modifiers=classvarModifiers)?
                      Vars=classVarList
                      eos
                    ;
*/         
         VAR  result := List<XElement>{}
         VAR classvars := ParseClassVarList(Kind.Field)
         LOCAL first := TRUE AS LOGIC
         FOREACH classvar AS XElement IN classvars
            VAR element := XTypeMember{classVar:Name, Kind.Field, _mods, _vis, classvar:Range, classvar:Interval, classvar:Typename, FALSE} ;
               {SingleLine := TRUE, Range       := textRange{_start, lastToken}, Interval    := TextInterval{_start, lastToken}}
               element:File := SELF:_file
            result:Add(element)
         NEXT
         readLine()
         RETURN result  
         #endregion
         
      #region Enum
      PRIVATE METHOD ParseEnum() AS IList<XElement>
/*
enum_               : (Attributes=attributes)? (Modifiers=classModifiers)?
                      E=ENUM (Namespace=nameDot)? Id=identifier ((AS|INHERIT) Type=datatype)? e=eos
                      (Members+=enummember)+
                      END ENUM? EOS
                    ;
*/         
         IF SELF:La1 == XSharpLexer.ENUM
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         VAR id := ParseIdentifier()
         VAR type := ""
         IF Matches(XSharpLexer.AS)
            type := SELF:ParseAsIsType()
         ELSEIF Matches(XSharpLexer.INHERIT)
            Consume() // inherit clause
            type := SELF:ParseTypeName()
         ENDIF
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         VAR xType := XType{id, Kind.Enum, _mods, _vis, range, interval, _file} {ParentName := type}
         RETURN List<XElement>{} {xType}
         
      PRIVATE METHOD ParseEnumMember() AS IList<XElement>
/*
enummember          : (Attributes=attributes)? MEMBER? Id=identifier (Op=assignoperator Expr=expression)? eos
                    ;
*/         

         VAR att := SELF:ParseAttributes()
         IF SELF:La1 == XSharpLexer.MEMBER
            Consume()
         ELSE
            RETURN NULL
         ENDIF
         VAR strValue := ""
         VAR id := ParseQualifiedName()
         IF SELF:IsAssignOp(La1)
            Consume() // :=
            strValue := ParseExpression()
         ENDIF
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         VAR xMember := XTypeMember{id, Kind.EnumMember, _mods, _vis, range, interval, ""} {SingleLine := TRUE, @@Value := strValue}
         xmember:File := SELF:_file
         RETURN List<XElement>{} {xMember}
         
         #endregion
         
      #region VO Global, Define, Struct, Union
      PRIVATE METHOD ParseVOGlobals() AS IList<XElement>
/*
                    // [STATIC] GLOBAL [CONST] Identifier [:= Expression] [, Identifier2 [:= Expression2] ] [AS Type]
                    // STATIC          [CONST] Identifier [:= Expression] [, Identifier2 [:= Expression2] ] [AS Type]
voglobal            : (Attributes=attributes)? (Modifiers=funcprocModifiers)? Global=GLOBAL (Const=CONST)? Vars=classVarList end=EOS 
                    | (Attributes=attributes)? Static=STATIC (Const=CONST)? Vars=classVarList end=EOS
                    ;
*/         
         IF SELF:La1 == XSharpLexer.GLOBAL
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         IF La1 == XSharpLexer.CONST
            Consume()
         ENDIF
         VAR classvars := ParseClassVarList(Kind.VOGlobal)
         VAR  result := List<XElement>{}
         
         FOREACH classvar AS XElement IN classvars
            VAR element := XTypeMember{classVar:Name, Kind.VOGlobal, _mods, _vis, classvar:Range, classvar:Interval, classvar:Typename, FALSE}
            element:Range       := element:Range:WithEnd(lastToken)
            element:Interval    := element:Interval:WithEnd(lastToken)
            element:File := _file
            element:SingleLine := TRUE
            result:Add(element)
         NEXT
         readLine()
         RETURN result
         
      PRIVATE METHOD ParseVoDefine() AS IList<XElement>
/*
vodefine            : (Modifiers=funcprocModifiers)?
                      D=DEFINE Id=identifier Op=assignoperator Expr=expression (AS DataType=typeName)? end=EOS
                    ;

*/         
         IF SELF:La1 == XSharpLexer.DEFINE
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         VAR id := ParseQualifiedName()
         LOCAL strValue AS STRING
         IF SELF:IsAssignOp(La1)
            Consume() // :=
            strValue := ParseExpression()
         ENDIF
         VAR type := SELF:ParseAsIsType()
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         
         VAR xmember := XTypeMember{id, Kind.VoDefine, _mods, _vis, range,interval, type} {SingleLine := TRUE, @@Value := strValue}
         xmember:File := SELF:_file
         RETURN List<XElement>{} {xmember}
         
      PRIVATE METHOD ParseVoStruct() AS IList<XElement>
/*
vostruct            : (Modifiers=votypeModifiers)?
                      V=VOSTRUCT (Namespace=nameDot)? Id=identifier (ALIGN Alignment=INT_CONST)? e=eos
                      (Members+=vostructmember)+
                      (END VOSTRUCT EOS)?
                    ;
*/         
         IF SELF:La1 == XSharpLexer.VOSTRUCT
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         VAR id := ParseQualifiedName()
         VAR sAlign := ""
         IF La1 == XSharpLexer.ALIGN .AND. La2 == XSharpLexer.INT_CONST
            sAlign := SELF:Lt2:GetText() // Align number
            Consume()
            Consume()
         ENDIF
         // read to EndOfLine
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xType := XType{id, Kind.VOStruct, _mods, _vis, range, interval,_file}
         IF String.IsNullOrEmpty(sAlign)
            xType:AddInterface(sAlign)
         ENDIF
         RETURN List<XElement>{} {xType}         
         
      PRIVATE METHOD ParseVOUnion() AS IList<XElement>
/*
vounion             : (Modifiers=votypeModifiers)?
                      U=UNION (Namespace=nameDot)? Id=identifier e=eos
                      (Members+=vostructmember)+
                      (END UNION EOS)?
                    ;
*/         
        IF SELF:La1 == XSharpLexer.UNION
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         VAR id := ParseQualifiedName()
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xtype := XType{id, Kind.Union, _mods, _vis, range, interval,_file}
         RETURN List<XElement>{} {xtype}         
         
      PRIVATE METHOD ParseVODLL() AS IList<XElement>
/*

vodll               : (Attributes=attributes)? (Modifiers=funcprocModifiers)? // Optional
                      D=DLL T=(FUNCTION|PROCEDURE) Id=identifier ParamList=parameterList (AS Type=datatype)? 
                      (CallingConvention=dllcallconv)? COLON
                      Dll=identifierString (DOT Extension=identifierString)?
                      (	Ordinal=REAL_CONST 
                       |  DOT Entrypoint=identifierString Address=ADDROF? Number=INT_CONST? (NEQ2 INT_CONST)? 
                      )
                       
                      ( CharSet=(AUTO | ID) )?  // ID must be either ANSI or UNICODE
                      EOS
                    ;

*/        
         IF SELF:La1 == XSharpLexer.DLL
            Consume()
         ELSE
            RETURN NULL
         ENDIF

         VAR t := ConsumeAndGet()
         VAR id := ParseQualifiedName()
         VAR aParams := SELF:ParseParameterList()
         VAR sType   := SELF:ParseAsIsType()
         VAR cc      := SELF:ParseCallingConvention()
         VAR colon   := SELF:ConsumeAndGetText()
         VAR dllName := SELF:ConsumeAndGetText()
         VAR dotName := ""
         IF Matches(XSharpLexer.DOT)
            Consume()
            dotName := SELF:ConsumeAndGetText()
         ENDIF
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         VAR xMember := XTypeMember{id, Kind.VODLL, _mods, _vis, range, interval,sType, _mods:HasFlag(Modifiers.Static)} {CallingConvention := cc, SubType := t:GetText()} 
         xmember:File := SELF:_file
         xMember:AddParameters(aParams)
         RETURN List<XElement>{} {xMember}         
         
         
      PRIVATE METHOD ParseVoStructMember() AS IList<XElement>
/*
vostructmember      : MEMBER Dim=DIM Id=identifier LBRKT ArraySub=arraysub RBRKT (As=(AS | IS) DataType=datatype)? eos
                    | MEMBER Id=identifier (As=(AS | IS) DataType=datatype)? eos
                    ;
*/         
         IF SELF:La1 == XSharpLexer.MEMBER
            Consume()
         ELSE
            RETURN NULL
         ENDIF
         
         LOCAL isArray AS LOGIC
         LOCAL sBracket AS STRING
         IF Matches(XSharpLexer.DIM)
            // read optional DIM clause
            isArray := TRUE
            Consume()
         ENDIF
         VAR id := ParseQualifiedName()
         IF isArray
            sBracket := ParseArraySub()
         ENDIF
         VAR sType := SELF:ParseAsIsType()
         VAR range    := textRange{_start, lastToken}
         VAR interval := textInterVal{_start, lastToken} 
         readLine()
         IF isArray
            sType += "[]"
         ENDIF
         VAR xMember := XTypeMember{id, Kind.Field, _mods, _vis, range, interval, sType} {SingleLine := TRUE, IsArray := isArray}
         xmember:File := SELF:_file
         RETURN List<XElement>{} {xMember}         
         
         #endregion
      PRIVATE METHOD CopySignatureValues(xmember AS XTypeMember, sig AS XSignature) AS VOID
         IF sig:Parameters?:Count > 0
            xmember:AddParameters(sig:Parameters)
         ENDIF
         IF sig:TypeParameters?:Count > 0
            FOREACH VAR par IN sig:TypeParameters
               xmember:AddTypeParameter(par)
            NEXT
         ENDIF
         IF sig:TypeParameterContraints:Count > 0
            FOREACH VAR constr IN sig:TypeParameterContraints
               xmember:AddConstraints(constr)
            NEXT
         ENDIF
         xmember:CallingConvention := sig:CallingConvention
         // typename was already set when creating xMember
         
         
      PRIVATE METHOD ParseClassVarList(eKind AS Kind)   AS IList<Xelement>
/*

classVarList        : Var+=classvar (COMMA Var+=classvar)* (As=(AS | IS) DataType=datatype)?
                    ;
*/         
         LOCAL aVars  AS List<Xelement>
         LOCAL sType  AS STRING
         aVars := List<Xelement>{}
         aVars:Add(ParseClassVar(eKind))
         DO WHILE La1 == XSharpLexer.COMMA
            SELF:Consume()
            aVars:Add(ParseClassVar(eKind))
         ENDDO
         sType := SELF:ParseAsisType()
         FOREACH VAR element IN aVars
            element:TypeName := sType
         NEXT
         RETURN aVars            
         
         
         
      PRIVATE METHOD ParseClassVar(eKind AS Kind) AS XeLement
/*

classvar            : (Dim=DIM)? Id=identifier (LBRKT ArraySub=arraysub RBRKT)? (Op=assignoperator Initializer=expression)?
                    ;
*/         
         LOCAL IsDim  := FALSE  AS LOGIC
         LOCAL sId        AS STRING
         LOCAL sDefault   AS STRING
         LOCAL startToken AS IToken
         LOCAL endToken   AS IToken
         startToken := Lt1
         IF La1 == XSharpLexer.DIM
            isDim := TRUE
            SELF:Consume()
         ENDIF
         sId  := SELF:ParseIdentifier()
         VAR sBracket  := ParseArraySub()
         IF IsAssignOp(La1)
            Consume()   // :=
            sDefault := SELF:ParseExpression()
         ENDIF
         endToken := SELF:lastToken
         VAR range    := textRange{startToken, endToken}
         VAR interval := TextInterVal{startToken, endToken}
         VAR result := XElement{sId,eKind, Modifiers.None, Modifiers.None, range,interval}
         result:Value := sDefault
         IF IsDim .OR. !String.IsNullOrEmpty(sBracket)
            result:IsArray := TRUE
         ENDIF
         RETURN result
         
      
      PRIVATE METHOD ParseArraySub AS STRING
/*
arraysub            : ArrayIndex+=expression (RBRKT LBRKT ArrayIndex+=expression)+		// x][y
                    | ArrayIndex+=expression (COMMA ArrayIndex+=expression)+			// x,y
                    | ArrayIndex+=expression
                    ;
*/
         LOCAL sBracket:= "" AS STRING      
         DO WHILE La1 == XSharpLexer.LBRKT           // allow SomeId[1][2]
            sBracket += SELF:ConsumeAndGetText()
            DO WHILE La1 != XSharpLexer.RBRKT .AND. ! SELF:Eos()        
               sBracket += SELF:ConsumeAndGetText()
            ENDDO
            IF La1 == XSharpLexer.RBRKT
               sBracket += SELF:ConsumeAndGetText()
            ENDIF
         ENDDO
         RETURN sBracket


      PRIVATE METHOD ParseSignature() AS XSignature
/*
signature             : Id=identifier                             
                      TypeParameters=typeparameters?                            
                      (ParamList=parameterList)?                                
                      (AS Type=datatype)?                                       
                      (ConstraintsClauses+=typeparameterconstraintsclause)*     
                      (CallingConvention=callingconvention)?
                      ;


*/
         LOCAL oSig          AS XSignature
         oSig                := XSignature{}
         oSig:Id             := SELF:ParseQualifiedName()
         IF La1 == XSharpLexer.LT
            oSig:TypeParameters := SELF:ParseTypeParameters()
         ENDIF
         IF La1 == XSharpLexer.LPAREN
            oSig:Parameters := SELF:ParseParameterList()
         ENDIF
         oSig:DataType       := SELF:ParseAsIsType()
         DO WHILE La1 == XSharpLexer.WHERE .AND. ! Eos()
            oSig:TypeParameterContraints:Add(SELF:ParseTypeParameterConstraints())
         ENDDO
         oSig:CallingConvention  := SELF:ParseCallingConvention()
         RETURN oSig
         
         
         
      PRIVATE METHOD ParseTypeParameters AS List<STRING>
         IF La1 != XSharpLexer.LT
            RETURN NULL
         ENDIF
         Consume()
         VAR aTypeParams := List<STRING>{}
         DO WHILE La1 != XSharpLexer.GT .AND. !Eos()
            VAR sParam := SELF:TokensAsString(ParseAttributes())
            
            IF La1 == XSharpLexer.IN .OR. La1 == XSharpLexer.OUT
               sParam += ConsumeAndGetText()+" "
            ENDIF
            IF SELF:IsId(La1)
               sParam += ConsumeAndGetText()
            ENDIF
            aTypeParams:Add(sParam)
            IF La1 == XSharpLexer.COMMA
               Consume()
            ENDIF
         ENDDO
         IF La1 == XSharpLexer.GT
            Consume()
         ENDIF
         RETURN aTypeParams 
         
         
         
      PRIVATE METHOD ParseParameterList(lBracketed := FALSE AS LOGIC) AS List<XVariable>
         IF La1 != XSharpLexer.LPAREN .AND. ! lBracketed
            RETURN NULL
         ENDIF
         IF La1 != XSharpLexer.LBRKT .AND. lBracketed
            RETURN NULL
         ENDIF
         Consume()   // LParen
         VAR aResult  := List<XVariable>{}
         VAR start := Lt1
         LOCAL cond AS DelEndToken
         cond := { token => IIF (lBracketed, token == XSharpLexer.RBRKT, token == XSharpLexer.RPAREN ) }
         DO WHILE !cond(La1) .AND. ! Eos()
            VAR atts := SELF:TokensAsString(ParseAttributes())
            VAR isSelf := FALSE 
            VAR sId   := ""
            VAR sTypeName := ""
            IF La1 == XSharpLexer.SELF
               isSelf := TRUE
               Consume()
            ENDIF
            IF SELF:IsId(La1)
               sId  += SELF:ConsumeAndGetText()
            ENDIF
            IF IsAssignOp(La1)
               // parse default value
            ENDIF
            
            VAR token := SELF:ConsumeAndGetAny(XSharpLexer.AS, XSharpLexer.IN, XSharpLexer.OUT, XSharpLexer.REF,XSharpLexer.PARAMS)
            IF token != NULL
               IF La1 == XSharpLexer.CONST
                  Consume()
               ENDIF
               sTypeName := SELF:ParseTypeName()
            ENDIF
            LOCAL variable AS XVariable
            VAR endToken := SELF:lastToken
            VAR range    := textRange{_start, lastToken}
            VAR interval := textInterVal{_start, lastToken}
            
            variable := XVariable{NULL, sId, Kind.Parameter,range,interval, sTypeName, TRUE}
            IF token != NULL
               SWITCH token:Type
               CASE XSharpLexer.AS
                  variable:ParamType := ParamType.As
               CASE XSharpLexer.IN
                  variable:ParamType := ParamType.In
               CASE XSharpLexer.OUT
                  variable:ParamType := ParamType.Out
               CASE XSharpLexer.REF
                  variable:ParamType := ParamType.Ref
               CASE XSharpLexer.PARAMS
                  variable:ParamType := ParamType.Params
               END SWITCH
            ENDIF
            aResult:Add(variable)
            IF La1 == XSharpLexer.COMMA
               Consume()
            ELSE
               EXIT
            ENDIF
         ENDDO
         IF Cond(La1)
            Consume()
         ENDIF
         RETURN aResult
         
         
      PRIVATE METHOD ParseTypeParameterConstraints() AS STRING
      
         IF La1 != XSharpLexer.WHERE
            RETURN ""
         ENDIF
         VAR result := SELF:ConsumeAndGetText() +" "
         IF SELF:IsId(La1) .AND. La2 == XSharpLexer.IS
            result     += SELF:ParseIdentifier() +" "
            result     += SELF:ConsumeAndGetText()+" "
            result     += SELF:ParseTypeParameterConstraint()+" "
            DO WHILE La1 == XSharpLexer.COMMA .AND. ! Eos()
               result += SELF:ConsumeAndGetText()+" "
               result     += SELF:ParseTypeParameterConstraint()+" "
            ENDDO
         ENDIF
         RETURN result
         
      PRIVATE METHOD ParseTypeParameterConstraint() AS STRING
         IF La1 == XSharpLexer.CLASS .OR. La1 == XSharpLexer.STRUCTURE
            RETURN ConsumeAndGetText()
         ELSEIF La1 == XSharpLexer.NEW .AND. La2 == XSharpLexer.LPAREN .AND. La3 == XSharpLexer.RPAREN
            RETURN "NEW()"
         ENDIF
         RETURN ParseTypeName()
         
         
         
      PRIVATE METHOD ParseAsIsType() AS STRING
         IF La1 == XSharpLexer.AS .OR. La1 == XSharpLexer.IS
            SELF:Consume()
            RETURN SELF:ParseTypeName()
         ENDIF
         RETURN ""
         
      PRIVATE METHOD ParseCallingConvention() AS STRING
/*
callingconvention	: Convention=(CLIPPER | STRICT | PASCAL | ASPEN | WINCALL | CALLBACK | FASTCALL | THISCALL)
                    ;
*/         
         SWITCH La1
         CASE XSharpLexer.CLIPPER
         CASE XSharpLexer.STRICT
         CASE XSharpLexer.PASCAL
         CASE XSharpLexer.ASPEN
         CASE XSharpLexer.WINCALL
         CASE XSharpLexer.CALLBACK
         CASE XSharpLexer.FASTCALL
         CASE XSharpLexer.THISCALL
            RETURN SELF:ConsumeAndGetText()
         END SWITCH
         RETURN ""
         
         
      PRIVATE METHOD IsAssignOp (nToken AS LONG) AS LOGIC
         RETURN nToken == XSharpLexer.ASSIGN_OP .OR. nToken == XSharpLexer.EQ
         
      PRIVATE METHOD ParseTypeName() AS STRING
         LOCAL result := "" AS STRING
         SWITCH La1
            
         CASE XSharpLexer.ID
            result := SELF:ParseQualifiedName() 
            
         CASE XSharpLexer.ARRAY
         CASE XSharpLexer.CODEBLOCK
         CASE XSharpLexer.DATE
         CASE XSharpLexer.FLOAT
         CASE XSharpLexer.PSZ
         CASE XSharpLexer.SYMBOL
         CASE XSharpLexer.USUAL
            result :=  ConsumeAndGet():GetText() 
            CASE XSharpLexer.BYTE
            CASE XSharpLexer.CHAR
            CASE XSharpLexer.DATETIME
            CASE XSharpLexer.DECIMAL
            CASE XSharpLexer.DWORD
            CASE XSharpLexer.DYNAMIC
            CASE XSharpLexer.INT
            CASE XSharpLexer.INT64
            CASE XSharpLexer.LOGIC
            CASE XSharpLexer.LONGINT
            CASE XSharpLexer.OBJECT
            CASE XSharpLexer.PTR
            CASE XSharpLexer.REAL4
            CASE XSharpLexer.REAL8
            CASE XSharpLexer.SHORTINT
            CASE XSharpLexer.STRING
            CASE XSharpLexer.UINT64
            CASE XSharpLexer.VOID
         CASE XSharpLexer.WORD
            result :=  SELF:ConsumeAndGet():GetText() 
         OTHERWISE
            IF XSharpLexer.IsKeyword(La1)
               result :=  SELF:ConsumeAndGet():GetText() 
            ENDIF
         END SWITCH
         IF result:Length > 0
            result += ParseTypeSuffix()
         ENDIF
         RETURN result
         

      PRIVATE METHOD ParseTypeSuffix AS STRING
         IF La1 == XSharpLexer.PTR
            RETURN " "+SELF:ConsumeAndGet():GetText()
         ELSEIF La1 = XSharpLexer.QMARK
            RETURN " "+SELF:ConsumeAndGet():GetText()
         ELSEIF La1 == XSharpLexer.LBRKT
            VAR tokens := List<IToken>{}
            tokens:Add(SELF:ConsumeAndGet())
            LOCAL closed := FALSE AS LOGIC
            DO WHILE ! Eos() .AND. ! closed
               SWITCH La1
               CASE XSharpLexer.RBRKT
                  tokens:Add(SELF:ConsumeAndGet())
                  closed := TRUE
               CASE XSharpLexer.COMMA
                  tokens:Add(SELF:ConsumeAndGet())
               OTHERWISE
                  closed := TRUE
               END SWITCH
            ENDDO
            RETURN SELF:TokensAsString(tokens)
         ELSEIF La1 == XSharpLexer.LT
            VAR result := ""
            DO WHILE La1 != XSharpLexer.GT .AND. ! Eos()
               result += SELF:ConsumeAndGetText()
            ENDDO
            IF La1 == XSharpLexer.GT 
               result += SELF:ConsumeAndGetText()
            ENDIF
            RETURN result
              
         ENDIF
         RETURN ""
         
         
      PRIVATE METHOD ParseExpressionAsTokens AS IList<IToken>
         // parse until Eos() or tokens such as AS, IS, 
         LOCAL nested := 0 AS LONG
         LOCAL done  := FALSE AS LOGIC
         VAR tokens := List<IToken>{}
         
         DO WHILE ! eos() .AND. ! done
            SWITCH La1
               CASE XSharpLexer.LPAREN
               CASE XSharpLexer.LBRKT
            CASE XSharpLexer.LCURLY
               nested++
               CASE XSharpLexer.RPAREN
               CASE XSharpLexer.RBRKT
            CASE XSharpLexer.RCURLY
                  nested--
                  
               CASE XSharpLexer.AS
               CASE XSharpLexer.IS
            CASE XSharpLexer.COMMA
                  // The comma is used for a comma separated list of expression.
                  // however inside a method call or constructor call we should have nested > 0
                  IF (nested == 0)
                     done := TRUE
                  ENDIF
               
            OTHERWISE
                  // other keywords, operators etc.
                  // 
               NOP
            END SWITCH
            IF !done
               tokens:Add(ConsumeAndGet())
            ENDIF
         ENDDO
         RETURN tokens         
      PRIVATE METHOD ParseExpression() AS STRING
         RETURN TokensAsString(SELF:ParseExpressionAsTokens())
        
         
         
      PRIVATE METHOD ParseStatement() AS VOID
         IF ! SELF:_collectLocals
            SELF:ReadLine()
            RETURN
         ENDIF
         SWITCH La1
         CASE XSharpLexer.LOCAL
         CASE XSharpLexer.STATIC
         CASE XSharpLexer.VAR
            IF ! SELF:ParseDeclarationStatement()
               SELF:ReadLine()
            ENDIF
         OTHERWISE
            // Check for method call with OUT VAR or OUT id AS TYPE
            SELF:ReadLine()
         END SWITCH
         RETURN
         
      PRIVATE METHOD ParseDeclarationStatement() AS LOGIC
//
//localdecl          : LOCAL (STATIC=STATIC)? LocalVars+=localvar (COMMA LocalVars+=localvar)*			END=eos #commonLocalDecl	
//                   | STATIC=STATIC LOCAL    LocalVars+=localvar (COMMA LocalVars+=localvar)*			END=eos #commonLocalDecl	
//                   | {!XSharpLexer.IsKeyword(InputStream.La(2))}?   // STATIC Identifier , but not STATIC <Keyword>
//                     STATIC=STATIC          LocalVars+=localvar (COMMA LocalVars+=localvar)*			END=eos #commonLocalDecl
//                   // The following rules allow STATIC in the parser, 
//                   // but the treetransformation will produce an error 9044 for STATIC implied
//                   | STATIC=STATIC? VAR           ImpliedVars+=impliedvar (COMMA ImpliedVars+=impliedvar)*  END=eos #varLocalDecl
//                   | STATIC=STATIC LOCAL? IMPLIED ImpliedVars+=impliedvar (COMMA ImpliedVars+=impliedvar)*  END=eos #varLocalDecl
//                   | LO

         LOCAL lStatic AS LOGIC
         LOCAL lImplied := FALSE AS LOGIC
         IF SELF:La1 == XSharpLexer.LOCAL
            Consume()
            IF SELF:La1 == XSharpLexer.STATIC
               lStatic := TRUE
               Consume()
            ENDIF
            IF SELF:La1 == XSharpLexer.IMPLIED
               lImplied := TRUE
               Consume()
            ENDIF
            IF SELF:La1 == XSharpLexer.STATIC
               lStatic := TRUE
               Consume()
            ENDIF
         ELSEIF SELF:La1 == XSharpLexer.STATIC
            lStatic := TRUE
            Consume()
            IF SELF:La1 == XSharpLexer.LOCAL
               Consume()
            ELSEIF SELF:La1 == XSharpLexer.VAR
               Consume()
               lImplied  := TRUE
            ELSEIF XSharpLexer.IsKeyword(La1)      // STATIC Keyword should exit
               RETURN FALSE
            ENDIF
            IF SELF:La1 == XSharpLexer.IMPLIED
               lImplied := TRUE
               Consume()
            ENDIF
         ELSEIF SELF:La1 == XSharpLexer.VAR
            Consume()
            lImplied  := TRUE
         ELSE
            RETURN FALSE
         ENDIF
         VAR result := List<XVariable>{}
         IF lImplied
            VAR xVar := SELF:ParseImpliedVar()
            result:Add(xVar)
            DO WHILE La1 == XSharpLexer.COMMA
               Consume()
               xVar := SELF:ParseImpliedVar()
               result:Add(xVar)
            ENDDO
         ELSE
            VAR xVar := SELF:ParseLocalVar()
            result:Add(xVar)
            DO WHILE La1 == XSharpLexer.COMMA
               Consume()
               xVar := SELF:ParseLocalVar()
               result:Add(xVar)
            ENDDO
         ENDIF
         // copy type forward
         VAR missingTypes := List<XVariable>{}
         FOREACH VAR xVar IN result
            IF xVar:TypeName == XVariable.NoType
               missingTypes:Add(xVar)
            ELSE
               IF MissingTypes:Count > 0
                  FOREACH VAR xMissing IN missingTypes
                     xMissing:TypeName := xVar:TypeName
                  NEXT
                  MissingTypes:Clear()
               ENDIF
            ENDIF
            SELF:_locals:Add(xVar)
         NEXT     
         FOREACH VAR xMissing IN missingTypes
            xMissing:TypeName := XVariable.UsualType
         NEXT
         RETURN TRUE

      PRIVATE METHOD ParseLocalVar AS XVariable
/*
//localvar           : (CONST=CONST)? ( DIM=DIM )? Id=identifier (LBRKT ArraySub=arraysub RBRKT)?
//                     (Op=assignoperator Expression=expression)? (AS=(AS | IS) DataType=datatype)?
//                   ;
*/
         LOCAL lConst   := FALSE AS LOGIC
         LOCAL lDim     := FALSE AS LOGIC
         LOCAL expr     AS IList<IToken>
         LOCAL start    := lt1 AS IToken
         IF La1 == XSharpLexer.CONST
            lConst := TRUE
            Consume()
         ENDIF
         IF La1 == XSharpLexer.DIM
            lDim := TRUE
            Consume()
         ENDIF
         VAR id := SELF:ParseIdentifier()
         VAR arraysub := ParseArraySub()
         IF SELF:IsAssignOp(La1)
            Consume()   // := operator
            expr       := ParseExpressionAsTokens()
         ENDIF
         VAR type     := SELF:ParseAsIsType()
         VAR range    := textRange{start, lastToken}
         VAR interval := textInterVal{start, lastToken} 
         IF String.IsNullOrEmpty(type)
            type := XVariable.NoType
         ENDIF
         VAR xVar     := XVariable{SELF:CurrentEntity, id, Kind.Local, range, interval, type} {IsArray := lDim .OR. !String.IsNullOrEmpty(arraySub)}
         IF type:EndsWith("[]")
            xVar:IsArray := TRUE
         ENDIF
         xVar:Expression := expr
         RETURN xVar

      PRIVATE METHOD ParseImpliedVar() AS XVariable
         // impliedvar: (Const=CONST)? Id=identifier Op=assignoperator Expression=expression         
         LOCAL lConst   := FALSE AS LOGIC
         LOCAL lDim     := FALSE AS LOGIC
         LOCAL expr     AS IList<IToken>
         LOCAL start    := lt1 AS IToken
         IF La1 == XSharpLexer.CONST
            lConst := TRUE
            Consume()
         ENDIF
         VAR id := SELF:ParseIdentifier()
         IF SELF:IsAssignOp(La1)
            Consume()   // := operator
            expr:= ParseExpressionAsTokens()
         ENDIF
         VAR range    := textRange{start, lastToken}
         VAR interval := textInterVal{start, lastToken} 
         VAR xVar     := XVariable{SELF:CurrentEntity, id, Kind.Local, range, interval, XVariable.VarType, FALSE} 
         xVar:Expression := expr
         RETURN xVar


      PRIVATE METHOD IsKeywordXs(token AS LONG) AS LOGIC
         SWITCH token
            CASE XSharpLexer.AUTO
            CASE XSharpLexer.CHAR
            CASE XSharpLexer.CONST
            CASE XSharpLexer.DEFAULT
            CASE XSharpLexer.GET
            CASE XSharpLexer.IMPLEMENTS
            CASE XSharpLexer.NEW
            CASE XSharpLexer.OUT
            CASE XSharpLexer.REF
            CASE XSharpLexer.SET
            CASE XSharpLexer.VALUE
            CASE XSharpLexer.VIRTUAL
            CASE XSharpLexer.INTERNAL
            CASE XSharpLexer.ADD
            CASE XSharpLexer.ARGLIST
            CASE XSharpLexer.ASCENDING
            CASE XSharpLexer.ASTYPE
            CASE XSharpLexer.ASYNC
            CASE XSharpLexer.AWAIT
            CASE XSharpLexer.BY
            CASE XSharpLexer.CHECKED
            CASE XSharpLexer.DESCENDING
            CASE XSharpLexer.DYNAMIC
            CASE XSharpLexer.EQUALS
            CASE XSharpLexer.EXTERN
            CASE XSharpLexer.FIXED
            CASE XSharpLexer.FROM 
            CASE XSharpLexer.GROUP
            CASE XSharpLexer.INTO
            CASE XSharpLexer.JOIN
            CASE XSharpLexer.LET
            CASE XSharpLexer.NAMEOF
            CASE XSharpLexer.OF
            CASE XSharpLexer.ON
            CASE XSharpLexer.ORDERBY
            CASE XSharpLexer.OVERRIDE
            CASE XSharpLexer.PARAMS
            CASE XSharpLexer.REMOVE 
            CASE XSharpLexer.SELECT
            CASE XSharpLexer.UNCHECKED
            CASE XSharpLexer.VAR
            CASE XSharpLexer.VOLATILE
            CASE XSharpLexer.WHERE
            CASE XSharpLexer.CURRENCY
            CASE XSharpLexer.DECIMAL
         CASE XSharpLexer.DATETIME 
               // Added as XS keywords to allow them to be treated as IDs
            // the following entity keywords will be never used 'alone' and can therefore be safely defined as identifiers
            CASE XSharpLexer.DELEGATE
            CASE XSharpLexer.ENUM
            CASE XSharpLexer.GLOBAL
            CASE XSharpLexer.INHERIT
         CASE XSharpLexer.STRUCTURE    
            // The following 'old' keywords are never used 'alone' and are harmless as identifiers
            CASE XSharpLexer.ALIGN
            CASE XSharpLexer.CALLBACK
            CASE XSharpLexer.CLIPPER
            CASE XSharpLexer.DIM
            CASE XSharpLexer.DOWNTO
            CASE XSharpLexer.DLLEXPORT  
            CASE XSharpLexer.FASTCALL
            CASE XSharpLexer.IN
            CASE XSharpLexer.INIT1
            CASE XSharpLexer.INIT2
            CASE XSharpLexer.INIT3
            CASE XSharpLexer.INSTANCE
            CASE XSharpLexer.PASCAL
            CASE XSharpLexer.SEQUENCE 
            CASE XSharpLexer.STEP
            CASE XSharpLexer.STRICT
            CASE XSharpLexer.TO
            CASE XSharpLexer.THISCALL
            CASE XSharpLexer.UPTO
            CASE XSharpLexer.USING
         CASE XSharpLexer.WINCALL 
               // The following keywords are handled in the fixPositionalKeyword() method of the lexer and will only be keywords at the right place
               // but when they code event->(DoSomething()) we still need them in this rule...
               //        CASE XSharpLexer.DEFINE
               //        CASE XSharpLexer.TRY
               //        CASE XSharpLexer.SWITCH
               //        CASE XSharpLexer.EVENT
               //        CASE XSharpLexer.EXPLICIT
               //        CASE XSharpLexer.FOREACH
               //        CASE XSharpLexer.UNTIL
               //        CASE XSharpLexer.PARAMETERS
               //        CASE XSharpLexer.YIELD
               //        CASE XSharpLexer.MEMVAR
               //        CASE XSharpLexer.NOP 
               //        CASE XSharpLexer.PARTIAL
               //        CASE XSharpLexer.SEALED
               //        CASE XSharpLexer.ABSTRACT
               //        CASE XSharpLexer.UNSAFE
               //        CASE XSharpLexer.SCOPE
               //        CASE XSharpLexer.NAMESPACE
               //        CASE XSharpLexer.LOCK
               //        CASE XSharpLexer.IMPLICIT
               //        CASE XSharpLexer.IMPLIED
               //        CASE XSharpLexer.INITONLY
               //        CASE XSharpLexer.PROPERTY
               //        CASE XSharpLexer.INTERFACE
               //        CASE XSharpLexer.VOSTRUCT
               //        CASE XSharpLexer.UNION
               //        CASE XSharpLexer.DECLARE
               //        CASE XSharpLexer.OPERATOR	
            RETURN TRUE
         END SWITCH
         // context sensitive keywords
         // ENDCLASS, FREEZE, FINAL, INTRODUCE, SYNC, DEFERRED, INLINE
         
         RETURN FALSE
         
      PRIVATE METHOD IsKeywordXpp(token AS LONG) AS LOGIC
         SWITCH token
            CASE XSharpLexer.SHARING
            CASE XSharpLexer.SHARED
            CASE XSharpLexer.ASSIGNMENT
            CASE XSharpLexer.EXPORTED
            CASE XSharpLexer.READONLY
         CASE XSharpLexer.NOSAVE
            RETURN TRUE
         END SWITCH
         RETURN FALSE
         
      PRIVATE METHOD IsKeywordFox(token AS LONG) AS LOGIC
         SWITCH token
            CASE XSharpLexer.OLEPUBLIC
            CASE XSharpLexer.EACH
            CASE XSharpLexer.EXCLUDE
            CASE XSharpLexer.THISACCESS
            CASE XSharpLexer.HELPSTRING
            CASE XSharpLexer.NOINIT
            CASE XSharpLexer.FOX_AND
            CASE XSharpLexer.FOX_OR
            CASE XSharpLexer.FOX_NOT
            CASE XSharpLexer.FOX_XOR
         CASE XSharpLexer.THEN
            RETURN TRUE
         END SWITCH
         // These tokens are already marked as 'only valid in a certain context ' in the lexer
         // ENDDEFINE | TEXT| ENDTEXT | DIMENSION | LPARAMETERS | NOSHOW | TEXTMERGE | PRETEXT | FLAGS | ADDITIVE
         
         RETURN FALSE
         
      STATIC METHOD GetText(SELF token AS IToken) AS STRING
         VAR result := token:Text
         IF result:StartsWith("@@")
            result := result:Substring(2)
         ENDIF
         RETURN result
      
   END CLASS
   
   DELEGATE DelEndToken(iToken AS LONG) AS LOGIC
   
   
   
END NAMESPACE












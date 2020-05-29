//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
USING System
USING System.Collections.Generic
USING System.Collections.Immutable
USING System.Linq
USING System.Text
USING System.Threading.Tasks
USING LanguageService.CodeAnalysis.Text
USING LanguageService.CodeAnalysis.XSharp
USING System.Diagnostics
USING System.Collections.Immutable

BEGIN NAMESPACE XSharpModel
	/// <summary>
	/// Model for Namespace, Class, Interface, Structure, Enum
	/// </summary>
	[DebuggerDisplay("{Kind}, {Name,nq}")];
	CLASS XType INHERIT XElement
		PRIVATE _isPartial AS LOGIC
		PRIVATE _members AS List<XTypeMember>
        PRIVATE _children AS List<XType>
		PRIVATE _nameSpace AS STRING
		PRIVATE _parentName AS STRING
        PRIVATE _interfaces AS List<STRING>
        PRIVATE _typeParameters AS List<STRING>
        PRIVATE _constraints    AS List<STRING>
        

		CONSTRUCTOR(name AS STRING, kind AS Kind, modifiers AS Modifiers, visibility AS Modifiers, ;
		    span AS TextRange, position AS TextInterval, oFile AS XFile)
			SUPER(name, kind, modifiers, visibility, span, position)
            SELF:_interfaces := List<STRING>{}
			SELF:_members  := List<XTypeMember>{}
            SELF:_children := List<XType>{}
			SELF:_parentName := "System.Object"
			SELF:_nameSpace := ""
			IF modifiers:HasFlag(Modifiers.Static)
				SELF:_isStatic := TRUE
			ENDIF
			IF modifiers:HasFlag(Modifiers.Partial)
				SELF:_isPartial := TRUE
			ENDIF
			SELF:File := oFile

			/// <summary>
			/// Duplicate the current Object, so we have the same properties in another object
			/// </summary>
			/// <returns></returns>
		CONSTRUCTOR( oOther AS XType)
			SELF(oOther:Name, oOther:Kind, oOther:Modifiers, oOther:Visibility, oOther:Range, oOther:Interval, oOther:File)
			SELF:Parent := oOther:Parent
			SELF:ParentName := oOther:ParentName
			SELF:IsPartial := oOther:IsPartial
			SELF:IsStatic := oOther:IsStatic
			SELF:NameSpace := oOther:NameSpace
			SELF:AddMembers(oOther:Members)
			RETURN


      /*
		STATIC METHOD create(oFile AS XFile, oElement AS EntityObject, oInfo AS ParseResult, dialect AS XSharpDialect ) AS XType
			LOCAL cName := oElement:cName AS STRING
			LOCAL kind  := Etype2Kind(oElement:eType) AS Kind
			LOCAL mods  := oElement:eModifiers:ToModifiers() AS Modifiers
			LOCAL vis   := oElement:eAccessLevel:ToModifiers() AS Modifiers
			LOCAL span  AS TextRange
			LOCAL intv  AS TextInterval
			LOCAL oXType AS XType
			mods &= ~Modifiers.VisibilityMask	// remove lower 2 nibbles which contain visibility

			CalculateRange(oElement, oInfo, OUT span, OUT intv)
			oXType := XType{cName, kind, mods, vis, span, intv, oFile}
			oXType:Dialect := dialect
			oXType:NameSpace := oElement:cClassNamespace
			oXType:ParentName := oElement:cInherit
			IF String.IsNullOrEmpty(oXType:ParentName) .AND. ! oXType:IsPartial
				oXType:ParentName := "System.Object"
			ENDIF
			oElement:oCargo := oXType
			IF oElement:eType:IsType()
				FOREACH VAR oMember IN oElement:aChildren
					LOCAL xMember AS XTypeMember
                    // HACK:
                    // At this moment the parser (incorrectly) generates VODefines for a DEFINE CLASS (VFP class def)
                    // these do not have a name. I am suppressing these to prevent problems elsewhere
                    IF !String.IsNullOrEmpty(oMember:cName )
					    xMember := XTypeMember.create(oMember, oInfo, oFile, oXType, dialect)
					    oMember:oCargo := xMember
					    oXType:AddMember(xMember)
                    ENDIF
				NEXT
				IF oXType.Kind == Kind.Delegate
					// Add "pseudo method" for the delegate for the editor
					LOCAL xMember AS XTypeMember
					xMember := XTypeMember.Create(oElement, oInfo, oFile, oXType,dialect)
					oXType:AddMember(xMember)
				ENDIF
			ENDIF

			RETURN oXType


       
         */
         METHOD AddInterface(sInterface AS STRING) AS VOID
            SELF:_interfaces:Add(sInterface)
            RETURN

		METHOD AddChild(oChild AS xType) AS VOID
			BEGIN LOCK SELF:_children
				SELF:_children:Add(oChild)
				oChild:Parent := SELF
			END LOCK


		METHOD AddMember(oMember AS XTypeMember) AS VOID
			BEGIN LOCK SELF:_members
				SELF:_members:Add(oMember)
				oMember:Parent := SELF
			END LOCK

		METHOD AddMembers(members AS IEnumerable<XTypeMember>) AS VOID
			BEGIN LOCK SELF:_members
				SELF:_members:AddRange(members)
				FOREACH VAR oMember IN members
					oMember:Parent := SELF
				NEXT
			END LOCK

       METHOD AddTypeParameter(name AS STRING) AS VOID
            IF SELF:_typeParameters == NULL
                SELF:_typeParameters := List<STRING>{}
            ENDIF
            SELF:_typeParameters:Add(name)
            RETURN

        METHOD AddConstraints(name AS STRING) AS VOID
            IF SELF:_constraints == NULL
                SELF:_constraints := List<STRING>{}
            ENDIF
            SELF:_constraints:Add(name)
            RETURN



        PROPERTY Interfaces AS IList<STRING>
        GET
			BEGIN LOCK SELF:_interfaces
				RETURN SELF:_interfaces:ToArray()
			END LOCK
        END GET
        END PROPERTY

		PROPERTY Members AS IList<XTypeMember>
			GET
				BEGIN LOCK SELF:_members
					RETURN SELF:_members:ToArray()
				END LOCK
			END GET
		END PROPERTY


		METHOD GetMember(elementName AS STRING) AS IList<XTypeMember>
			VAR tempMembers := List<XTypeMember>{}
			FOREACH x AS XTypeMember IN SELF:Members
				IF nameEquals(x:Name, elementName)
					tempMembers:Add(x)
				ENDIF
			NEXT
			RETURN tempMembers;

			PRIVATE METHOD nameEquals(name AS STRING, compareWith AS STRING) AS LOGIC
			RETURN String.Compare(name, compareWith, StringComparison.OrdinalIgnoreCase) == 0


		PROPERTY FullName AS STRING
			GET
				IF ! String.IsNullOrEmpty(SELF:_nameSpace)
					RETURN SELF:NameSpace + "." + SUPER:Name
				ENDIF
				RETURN SUPER:Name
			END GET
		END PROPERTY


		/// <summary>
		/// Merge two XType Objects : Used to create the resulting  XType from partial classes
		/// </summary>
		/// <param name="otherType"></param>
		METHOD Merge(otherType AS XType) AS XType
			LOCAL clone AS XType
			clone := XType{SELF}
			IF (String.Compare(otherType:File:FullPath, SUPER:File:FullPath, System.StringComparison.OrdinalIgnoreCase) != 0) .OR. (SUPER:Range:StartLine != otherType:Range:StartLine)
				SELF:IsPartial := TRUE
				IF otherType != NULL
					clone:AddMembers(otherType:Members)
					IF clone:Parent == NULL .AND. otherType:Parent != NULL
						clone:Parent := otherType:Parent
					ELSE
						IF clone:ParentName == NULL .AND. otherType:ParentName != NULL
							clone:ParentName := otherType:ParentName
						ENDIF
					ENDIF
				ENDIF
			ENDIF
			IF String.IsNullOrEmpty(clone:ParentName)
				clone:ParentName := "System.Object"
			ENDIF

			RETURN clone


		PROPERTY NameSpace AS STRING GET _namespace SET _namespace := VALUE

		/// <summary>
		/// If this XType is a Partial type, return a Copy of it, merged with all other informations
		/// coming from other files.
		/// </summary>

		PROPERTY Clone AS XType
			GET
				IF SELF:IsPartial .AND. SELF:File != NULL
					RETURN SUPER:File:Project:Lookup(SELF:FullName, TRUE)
				ENDIF
				RETURN SELF
			END GET
		END PROPERTY

		NEW PROPERTY Description AS STRING
			GET
				VAR modVis := ""
				IF SUPER:Kind == Kind.Class
					IF SUPER:Modifiers != Modifiers.None
						modVis := modVis + SUPER:Modifiers:ToString()+  " "
					ENDIF
					modVis := modVis + SUPER:Visibility:ToString()+ " "
					IF ( SELF:IsStatic )
						modVis += "STATIC "
					ENDIF
				ENDIF

				IF SUPER:Kind == Kind.Keyword
					RETURN SUPER:Name + " " + SUPER:Kind:ToString()
				ENDIF
				RETURN modVis + SUPER:Kind:ToString() + " " + SELF:Prototype
			END GET
		END PROPERTY


		PROPERTY IsPartial AS LOGIC GET SELF:_isPartial SET SELF:_isPartial := VALUE

		PROPERTY IsType AS LOGIC
			GET
				SWITCH SUPER:Kind
				CASE Kind.Class
					CASE Kind.Structure
					CASE Kind.VOStruct
					CASE Kind.Union
					CASE Kind.Interface
					CASE Kind.Enum
						RETURN TRUE
					END SWITCH
				RETURN FALSE
			END GET
		END PROPERTY



		PROPERTY ParentName AS STRING
			GET
				IF SUPER:Parent != NULL
					RETURN SUPER:Parent:Name
				ENDIF
				IF SELF:_parentName != NULL
					RETURN SELF:_parentName
				ENDIF
				RETURN NULL
			END GET
			SET
				IF SUPER:Parent != NULL
					THROW System.Exception{"Cannot set ParentName if Parent is not null"}
				ENDIF
				SELF:_parentName := VALUE
			END SET
		END PROPERTY


		STATIC METHOD CreateGlobalType(xfile AS XFile) AS XType
			VAR globalType := XType{GlobalName, Kind.Class, Modifiers.None, Modifiers.Public, TextRange{1, 1, 1, 1}, TextInterval{}, xfile}
			globalType:IsPartial:=TRUE
			globalType:IsStatic:=TRUE
			RETURN globalType

		STATIC METHOD IsGlobalType(type AS XElement) AS LOGIC
			RETURN type:Name == XType.GlobalName

        PROPERTY Children AS IList<XType> GET SELF:_children:ToArray()

	END CLASS

END NAMESPACE


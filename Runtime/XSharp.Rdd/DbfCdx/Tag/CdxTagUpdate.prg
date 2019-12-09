//
// Copyright (c) XSharp B.V.  All Rights Reserved.  
// Licensed under the Apache License, Version 2.0.  
// See License.txt in the project root for license information.
//
USING System
USING System.Collections
USING System.Collections.Generic
USING System.Diagnostics
USING System.Globalization
USING System.IO
USING System.Reflection
USING System.Text
USING System.Threading
USING XSharp.RDD.Enums
USING XSharp.RDD.Support
USING System.Linq
BEGIN NAMESPACE XSharp.RDD.CDX

    INTERNAL PARTIAL SEALED CLASS CdxTag
        // Methods for updating (adding, inserting, deleting) keys into indices
        PRIVATE METHOD _UpdateError(ex AS Exception, strFunction AS STRING, strMessage AS STRING) AS VOID
            SELF:RDD:_dbfError(ERDD.CREATE_ORDER, GenCode.EG_CORRUPTION, strFunction, strMessage+" for "+SELF:Filename+" "+SELF:OrderName )
            RETURN
            
        INTERNAL METHOD NewLeafPage() AS CdxLeafPage
            LOCAL oLeaf := NULL AS CdxLeafPage
            TRY
                LOCAL buffer AS BYTE[]
                buffer := _bag:AllocBuffer()
                oLeaf  := CdxLeafPage{_bag, -1, buffer, SELF:KeyLength}
                oLeaf:InitBlank(SELF)
                oLeaf:Write() // will give it a pagenumber
                //oLeaf:Debug("New Leaf", oLeaf:PageNo:ToString("X8"))
                SELF:OrderBag:SetPage(oLeaf)
            CATCH ex AS Exception
                _UpdateError(ex,"CdxTag.NewLeafPage","Could not allocate Leaf page")
            END TRY
            RETURN oLeaf

        INTERNAL METHOD NewBranchPage() AS CdxBranchPage
            LOCAL oBranch := NULL AS CdxBranchPage
            TRY
                LOCAL buffer AS BYTE[]
                // Allocate new Branch Page
                buffer  := _bag:AllocBuffer()
                oBranch := CdxBranchPage{_bag, -1, buffer, SELF:KeyLength}
                oBranch:InitBlank(SELF)
                oBranch:Tag    := SELF
                oBranch:Write() // will give it a pagenumber
                //oBranch:Debug("New Branch", oBranch:PageNo:ToString("X8"))
                SELF:OrderBag:SetPage(oBranch)
            CATCH ex AS Exception
                _UpdateError(ex,"CdxTag.NewBranchPage","Could not alPagelocate Branch page")
            END TRY
            RETURN oBranch




        INTERNAL METHOD DoAction(action AS CdxAction) AS CdxAction
            // Dispatcher that evaluates actions that have to be done.
            // action is a Flag value, so we look for each of the following actions
            // Index updates start with an attempt to Add a key (during index creation, keys are then added in correct order)
            // Insert Key (for new records)
            // or a Delete Key followed by an Insert Key (for Updates)
            // For conditional indexes an Update may also consist of just a Delete or just an Insert
            // Key operations are always done on Leaf pages (Foxpro calls this Exterior nodes)
            // When leaf pages get full or empty then key operations may also affect other pages
            // And also when the last key on a leaf page changes then this may trigger updates on the
            // branche pages above it.
            TRY
                DO WHILE action:Type != CdxActionType.OK
                    SWITCH action:Type
                    CASE CdxActionType.AddKey
                        // Called during index creation
                        action := SELF:AddKey(action)
                    CASE CdxActionType.DeleteKey
                        // after adding the leaf we want to write a new key to the newly allocated page
                        action := SELF:DeleteKey(action)

                    CASE CdxActionType.InsertKey
                        // after adding the leaf we want to write a new key to the newly allocated page
                        action := SELF:InsertKey(action)

                    CASE CdxActionType.AddLeaf
                        // after adding the leaf we want to write a new key to the newly allocated page
                        action := SELF:AddLeaf(action)

                    CASE CdxActionType.DeletePage
                        // this will return DeleteFromParent so we increase the next level
                        action := SELF:DeletePage(action)

                    CASE CdxActionType.ChangeParent
                        // when the last key of a page was changed we need to update the parent
                        action := SELF:ChangeParent(action)

                    CASE CdxActionType.InsertParent
                        // insert parent above current level on the stack
                        action := SELF:InsertParent(action)

                    CASE CdxActionType.AddBranch
                        // after adding the leaf we want to write a new key to the newly allocated page
                        action := SELF:AddBranch(action)

                    CASE CdxActionType.DeleteFromParent
                        // This removes the key for a page from its parent page
                        action := SELF:DeleteFromParent(action)

                    CASE CdxActionType.OutOfBounds
                        // Throw an exception
                        _UpdateError(NULL, "CdxTag.DoAction","Out of Bounds when writing to a page")
                        action := CdxAction.Ok
                    CASE CdxActionType.ExpandRecnos
                        // after expanding we either need to split or update the current page, so no nextlevel
                        action := SELF:ExpandRecnos(action)
                    OTHERWISE
                        _UpdateError(NULL, "CdxTag.DoAction","Unexpected Enum value "+action:Type:ToString())
                    END SWITCH
                ENDDO
            CATCH ex AS Exception
                _UpdateError(ex,"CdxTag.DoAction","Error performing action "+action:Type:ToString())

            END TRY
            RETURN action

        PRIVATE METHOD DeletePage(action AS CdxAction) AS CdxAction
            VAR oPage := SELF:GetPage(action:PageNo )
            IF oPage == NULL
                // Should not happen...
                _UpdateError(NULL, "CdxTag.DeletePage","DeletePage called without page reference")
                RETURN CdxAction.Ok
            ENDIF
            // now update the reference to this page in the parent node
            VAR oParent := SELF:Stack:GetParent(oPage)
            IF oParent == NULL
               // Then this was the top level leaf page. So the tag has no keys anymore is empty now
                oPage:SetEmptyRoot()
                SELF:OrderBag:FlushPages()
                SELF:ClearStack()
                RETURN CdxAction.OK
            ENDIF
            // remove from linked list of pages
            // Establish Link between our Left and Right
            // there should at least be a left or a right page
            // otherwise this level of the index was useless
            //Debug.Assert(oPage:HasLeft .or. oPage:HasRight)
            IF oPage:HasLeft
                VAR pageL := SELF:GetPage(oPage:LeftPtr)
                IF pageL != NULL
                    pageL:RightPtr := oPage:RightPtr
                    pageL:Write()
                ENDIF
                oPage:LeftPtr := -1
                // if oPageL has no LeftPtr .and. also no RightPtr then the level may be removed ?
                Debug.Assert(pageL:HasLeft .OR. pageL:HasRight)
            ENDIF
            IF oPage:HasRight
                VAR pageR := SELF:GetPage(oPage:RightPtr)
                pageR:LeftPtr := oPage:LeftPtr
                pageR:Write()
                oPage:RightPtr := -1
                // if oPageR has no LeftPtr .and. also no RightPtr then the level may be removed ?
                //Debug.Assert(pageR:HasLeft .or. pageR:HasRight)
            ENDIF
            SELF:OrderBag:FreePage(oPage)
            RETURN CdxAction.DeleteFromParent(oPage)

        PRIVATE METHOD DeleteFromParent(action AS CdxAction) AS CdxAction
            VAR oPage   := SELF:GetPage(action:PageNo) 
            VAR oParent := SELF:Stack:GetParent(oPage) ASTYPE CdxbranchPage
            VAR result := CdxAction.OK

            IF oParent != NULL_OBJECT
                // this can be the top level. In that case we should not get here at all
                LOCAL nPos AS LONG
                nPos := oParent:FindPage(action:PageNo)
                IF nPos != -1
                    result := oParent:Delete(nPos)
                ELSE
                    // Todo: this is a logical problem
                     _UpdateError(NULL, "CdxTag.DeleteFromParent","Could not find entry for child on parent page")
                ENDIF 
            ELSE
                _UpdateError(NULL, "CdxTag.DeleteFromParent","DeleteFromParent called when there is no Parent on the stack")
            ENDIF
            RETURN result

        INTERNAL METHOD FindParent(oPage AS CdxTreePage) AS CdxBranchPage
            VAR oParent   := SELF:Stack:Getparent(oPage) ASTYPE  CdxBranchPage
            IF oParent == NULL
                // walk the whole level to find the page above this one
                FOREACH VAR oLoop IN oPage:CurrentLevel
                    oParent := (CdxBranchPage) SELF:Stack:GetParent(oLoop)
                    IF oParent != NULL_OBJECT
                        EXIT
                    ENDIF
                NEXT
            ENDIF
            IF oParent != NULL
                IF oParent:FindPage(oPage:PageNo) == -1
                    LOCAL found := FALSE AS LOGIC
                    IF oParent:HasRight
                        VAR oRight := SELF:GetPage(oParent:RightPtr) ASTYPE CdxBranchPage
                        found   := oRight:FindPage(oPage:PageNo) != -1
                        IF found
                            oParent := oRight
                        ENDIF
                    ENDIF
                    IF ! found
                        oParent := (CdxBranchPage) oParent:FirstPageOnLevel
                        DO WHILE oParent != NULL .AND. oParent:FindPage(oPage:PageNo) == -1
                            IF oParent:HasRight
                                oParent := SELF:GetPage(oParent:RightPtr) ASTYPE CdxBranchPage
                            ELSE
                                oParent := NULL
                            ENDIF
                        ENDDO
                    ENDIF
                ENDIF
            ENDIF
            RETURN oParent

        INTERNAL METHOD ChangeParent(action AS CdxAction) AS CdxAction
            VAR oPage     := SELF:GetPage(action:PageNo)
            VAR oPage2    := SELF:GetPage(action:PageNo2)   // only filled after a pagesplit
            VAR oParent   := SELF:FindParent(oPage) 
            VAR result    := CdxAction.Ok
            VAR oLast     := oPage:LastNode
            LOCAL oGrandParent := NULL AS CdxBranchPage
//            ? "Changeparent", oPage:PageNo:ToString("X")
//            ? "Changeparent", oPage2:PageNo:ToString("X")
            IF oParent != NULL_OBJECT
                LOCAL nPos AS LONG
                nPos  := oParent:FindPage(oPage:PageNo)
                //? "Pos:", nPos
                IF nPos != -1 .AND. nPos < oParent:NumKeys
                    result := oParent:Replace(nPos, oLast)
                    SELF:DoAction(result)
                    IF oPage2 != NULL
                        IF nPos < oParent:NumKeys -1
                            result := oParent:Insert(nPos+1, oPage2:LastNode)
                        ELSE
                            result := oParent:Add(oPage2:LastNode)
                        ENDIF
                    ENDIF
                    oParent:Write()
                        
                    // when the last key of the parent was changed then
                    // we need to propagate that to the top
                    IF result:Type == CdxActionType.OK
                        IF nPos == oParent:NumKeys -1
                            oGrandParent := (CdxBranchPage) SELF:Stack:GetParent(oParent)
                        ENDIF
                    ENDIF
                ELSE
                    // Should no longer happen since we now pass 2 pages
                    result := SELF:AddToParent(oParent, action)
                    IF result:Type == CdxActionType.OK
                       oGrandParent := (CdxBranchPage) SELF:Stack:GetParent(oParent)
                    ENDIF
                ENDIF
            ENDIF
            IF oGrandParent != NULL
                result := CdxAction.ChangeParent(oParent)
            ENDIF
            RETURN result

        INTERNAL METHOD AddToParent(oParent AS CdxBranchPage, action AS CdxAction) AS CdxAction
            VAR oPage     := SELF:GetPage(action:PageNo)
            VAR result    := CdxAction.Ok
            VAR oLast     := oPage:LastNode
            // If the page was not on the Branch, then find the position where it has to goto
            // and insert it
            // when our key is after the last key, then make sure that we do not need to insert
            // the key on the Branch page to the right of the oParent

            // First check to see if the parent has room for an extra child node
            IF oParent:NumKeys >= oParent:MaxKeys
                VAR tmp := CdxAction.AddBranch(oParent, oPage:PageNo, oLast:Recno,oLast:KeyBytes )
                result := SELF:AddBranch(tmp)
                IF ! result.IsOk()
                    RETURN SELF:Doaction(result)
                ENDIF
            ENDIF
            // determine position where to insert the page
            LOCAL nPos AS LONG
            oLast    := oPage:LastNode
            nPos     := oParent:FindKey(oLast:KeyBytes, oLast:Recno, oLast:KeyBytes:Length)
            IF nPos >= oParent:NumKeys -1
                VAR nDiff := SELF:__Compare(oParent:LastNode:KeyBytes, oLast:KeyBytes, oLast:KeyBytes:Length)
                IF nDiff > 0
                    //oParent:Debug("Inserted", oPage:PageType, oPage:PageNo:ToString("X"), oPage:LastNode:KeyBytes:ToAscii())
                    result := oParent:Insert(nPos, oLast)
                ELSEIF nDiff == 0
                    nPos := oParent:NumKeys -1
                    IF oParent:GetRecno(nPos) > oLast:Recno
                        result := oParent:Insert(nPos, oLast)
                    ELSE
                        result := oParent:Add(oLast)
                    ENDIF
                ELSE
                    // Make sure that the key is not already inserted on the next page
                    LOCAL lMustAdd := TRUE AS LOGIC
                    IF oParent:HasRight
                        VAR oRightPage := (CdxBranchPage) SELF:GetPage(oParent:RightPtr)
                        IF oRightPage:FindPage(oLast:Page:PageNo) >= 0
                            lMustAdd := FALSE
                        ENDIF
                    ENDIF
                    IF lMustAdd
                        //oParent:Debug("Added", oPage:PageType, oPage:PageNo:ToString("X"), oPage:LastNode:KeyBytes:ToAscii())
                        result := oParent:Add(oLast)
                    ENDIF
                ENDIF
            ELSE
                result := oParent:Insert(nPos, oLast)
            ENDIF
            RETURN SELF:DoAction(result)

        INTERNAL METHOD InsertParent(action AS CdxAction) AS CdxAction
            // We assume the page in the action is the right of the two pages that need to get a parent
            // we don't want to change the root page. When running in shared mode
            // this could confuse other workstations, because the root page is in the Tag information
            // and this is most likely cached by other workstations.
            // (fictuous page numbers in parentheses after name)
            // So in the situation where the root page is full we would get a situation like this
            // After adding a new sibling (99) next to the old root a parent level is inserted that
            // would become the new root (100) and would contain 2 nodes, linking to the pages 50 and 99.
            /*
                               BRANCH  (e00) (2 nodes)
                            /             \
                           50             99
                           /               \
               LEAF = OLD ROOT (A00)   <-> NEW LEAF (c00)

                                and possibly more sublevels
            */
            // To prevent changing the root page number in the tag header we need to swap the content
            // of the pages of the old and new root, so the situation will be come this:
            /*
                               BRANCH (a00) (2 nodes)
                            /             \
                           100            99
                           /               \
                LEAF = NEW PAGE (e00)   <->   NEW LEAF (c00)

                                and possibly more sublevels

            */
            // We can do this by swapping the contents of the pages, but the references must also be adjusted.
            // The new root (100) has a first element that points to the old root (50) but this must be changed to 100.
            // This also means the Left and Right references of the pages on the first level must be adjusted.
            // The new sibling was pointing to the page of the old root (50) and must be changed to point
            // to the new page (100).
            // Also the old root could be a leaf page and the new root is always a branch page.
            // 
            // The only moment where we are writing a new root page number to the tag
            // header is when there was no RootPage in there

            LOCAL oNewRoot       AS CdxBranchPage
            LOCAL oNewSibling    AS CdxTreePage
            LOCAL oOldRoot       AS CdxTreePage
            oNewSibling          := SELF:GetPage(action:PageNo)
            // validate current level
            oNewRoot := SELF:NewBranchPage()
            //oTop:Debug(oTop:PageType, "stack depth after adding level", SELF:Stack:Count)
            IF oNewSibling:NumKeys > 0
                oNewRoot:Add(oNewSibling:LastNode)
            ENDIF
            // make sure new parent has both of its children
            IF oNewSibling:HasLeft
                oOldRoot := SELF:GetPage(oNewSibling:LeftPtr)
                IF oOldRoot != NULL_OBJECT
                    oNewRoot:Insert(0, oOldRoot:LastNode)
                ENDIF
            ELSE
                // Error
                oOldRoot := NULL
                _UpdateError(NULL,"CdxTag.InsertParent","Left page missing")
            ENDIF
            // now swap the pages for oNewRoot and oLeft
            SELF:_bag:_PageList:Delete(oNewRoot:PageNo)
            SELF:_bag:_PageList:Delete(oOldRoot:PageNo)
            LOCAL nNew      AS LONG
            LOCAL nOldRoot  AS LONG
            nNew      := oNewRoot:PageNo
            nOldRoot  := oOldRoot:PageNo
            //? "New branche page swaps place with root", nNew:ToString("X"), nOldRoot:ToString("X")
            VAR lWasRoot := oOldRoot:IsRoot
            // Adjust new sibling
            oNewSibling:LeftPtr := nNew
            oNewSibling:Write()
            // swap page numbers for both pages
            oOldRoot:PageNo     := nNew
            oOldRoot:ClearRoot()
            oOldRoot:Write()
            oNewRoot:PageNo    := nOldRoot
            oNewRoot:Replace(0, oOldRoot:LastNode)
            IF lWasRoot
                oNewRoot:SetRoot()
            ENDIF
            oNewRoot:Write()
            SELF:InsertOnTop(oNewRoot)
            RETURN CdxAction.Ok
        
        INTERNAL METHOD SetRoot(oPage AS CdxTreePage) AS VOID
            LOCAL oldRoot AS CdxTreePage
            IF _rootPage != oPage:PageNo
                oldRoot := SELF:GetPage(_rootPage)
                IF oldRoot != NULL .AND. oldRoot != oPage
                    IF oldRoot:IsRoot
                        oldRoot:ClearRoot()
                        oldRoot:Write()
                    ENDIF
                ENDIF
            ENDIF
            Header:RootPage := oPage:PageNo
            Header:Write()
            oPage:SetRoot()
            oPage:Write()
            _rootPage := oPage:PageNo
            RETURN

        INTERNAL METHOD AddBranch(action AS CdxAction) AS CdxAction
            LOCAL oPageR AS CdxBranchPage
            LOCAL oPageL  AS CdxBranchPage
            oPageL  := (CdxBranchPage) SELF:GetPage(action:PageNo)
            oPageR := SELF:NewBranchPage()
            //oPageR:Debug("Added", oPageR:PageType)
            //? "Branch", oPageR:PageNo:ToString("X"), "Added"
            oPageL:AddRightSibling(oPageR)
            //oPageL:Debug("Add branch after ", oPageL:PageNo:ToString("X8"), oPageR:PageNo:ToString("X8"), "Pos", Action:Pos, "Rec", Action:Recno)
            action := oPageL:Split(oPageR, action,TRUE)
            IF action:Type != CdxActionType.Ok
                _UpdateError(NULL,"CdxTag.AddBranch","Could not insert key into new Branch page")
            ENDIF

            IF oPageL:IsRoot
                //? "Insert Level above root", oPageL:PageNo:ToString("X"), oPageR:PageNo:ToString("X")
                action := CdxAction.InsertParent(oPageR)
                SELF:AdjustStack(oPageL, oPageR, oPageL:NumKeys)
            ELSE
                action := CdxAction.ChangeParent(oPageL, oPageR)
                action := SELF:Doaction(action)
                SELF:AdjustStack(oPageL, oPageR, oPageL:NumKeys)
                
            ENDIF
            RETURN action


        INTERNAL METHOD AddKey(action AS CdxAction) AS CdxAction
            // This is called during index creation.
            // Please note that we do not update the link to the parent on top
            // because that will slow down indexing
            // When the page is split then the topreference will be updated
            // and at the end of the indexing the top reference for the last page will be written.
            VAR page := SELF:Stack:Top:Page ASTYPE CdxLeafPage
            IF page IS CdxLeafPage VAR leaf
                action := leaf:Add(action:Recno, action:Key)
                IF action:Type == CdxActionType.OK
                    SELF:Stack:Top:Pos++
                ENDIF
            ELSE
                _UpdateError(NULL,"CdxTag.AddKey","Page is not a Leaf page")
            ENDIF
            RETURN action

        INTERNAL METHOD DeleteKey(action AS CdxAction) AS CdxAction
            IF SELF:GetPage(action:PageNo) IS CdxLeafPage VAR leaf
                RETURN leaf:Delete(action:Pos)
            ENDIF
            _UpdateError(NULL,"CdxTag.DeleteKey","Page is not a Leaf page")
            RETURN CdxAction.OK

        INTERNAL METHOD InsertKey(action AS CdxAction) AS CdxAction
            IF SELF:GetPage(action:PageNo) IS CdxLeafPage VAR leaf
                RETURN leaf:Insert(action:Pos, action:Recno, action:Key)
            ENDIF
            _UpdateError(NULL,"CdxTag.AddKey","Page is not a Leaf page")
            RETURN CdxAction.OK

   

        INTERNAL METHOD AddLeaf(action AS CdxAction) AS CdxAction
            // Allocate a new leaf page and add recno and key from action
            VAR oPageL      := SELF:GetPage(action:PageNo) ASTYPE CdxLeafPage
            VAR oPageR      := SELF:NewLeafPage()
            //oPageR:Debug("Added", oPageR:PageType)
            oPageL:AddRightSibling(oPageR)
            //? "Leaf", oPageR:PageNo:ToString("X"), "Added"
            IF action:Pos > -1
                action := oPageL:Split(oPageR, action)
            ELSE
                action := oPageR:Add(action:Recno, action:Key)
            ENDIF
            IF action:Type != CdxActionType.Ok
                _UpdateError(NULL,"CdxTag.AddLeaf","Could not insert key into new leaf page")
            ENDIF
            IF oPageL:IsRoot
                //? "Insert Level above root", oPageL:PageNo:ToString("X"), oPageR:PageNo:ToString("X")
                action := CdxAction.InsertParent(oPageR)
                SELF:AdjustStack(oPageL, oPageR, oPageR:NumKeys)
            ELSE
                action := CdxAction.ChangeParent(oPageL, oPageR)
                action := SELF:DoAction(action)
                SELF:AdjustStack(oPageL, oPageR, oPageL:NumKeys)
            ENDIF
            RETURN action

     
        PRIVATE METHOD ExpandRecnos(action AS CdxAction) AS CdxAction
            VAR oPageL   := SELF:CurrentLeaf
            VAR leaves   := oPageL:GetLeaves()
            LOCAL result AS CdxAction
            // Only allocate page when we think that it does not fit.
            // To be safe we assume expanding takes 1 byte per key + we want the new key to fit as well
            IF oPageL:FreeSpace > (oPageL:DataBytes + SELF:KeyLength + leaves:Count +1)
                SELF:SetLeafProperties(oPageL)
                oPageL:SetLeaves(leaves, 0, leaves:Count)
                result := oPageL:Insert(action:Pos, action:Recno, action:Key)
                RETURN result
            ENDIF
            VAR nHalf    := leaves:Count/2
            VAR oPageR   := SELF:NewLeafPage()
            oPageL:AddRightSibling(oPageR)
            SELF:SetLeafProperties(oPageL)
            result := oPageL:SetLeaves(leaves, 0, nHalf)
            IF ! result:IsOk()
                result := SELF:DoAction(result)
            ENDIF
            SELF:SetLeafProperties(oPageR)
            result := oPageR:SetLeaves(leaves, nHalf, leaves:Count - nHalf)
            IF ! result:IsOk()
                result := SELF:DoAction(result)
            ENDIF
            VAR pos := action:Pos
            IF  pos != -1
                //oPageL:Debug("Expand for recno ", action:Recno, "position", pos, "half", nHalf)
                IF pos < nHalf
                    result := oPageL:Insert(pos, action:Recno, action:Key)
                    
                ELSE
                    result := oPageR:Insert(pos - nHalf, action:Recno, action:Key)
                ENDIF
            ELSE
                result := oPageR:Add(action:Recno, action:Key)
            ENDIF
            IF ! result:IsOk()
                result := SELF:DoAction(result)
            ENDIF
            action := CdxAction.ChangeParent(oPageL, oPageR)
            result := SELF:DoAction(action)
            SELF:AdjustStack(oPageL, oPageR, oPageR:NumKeys)
            RETURN result
            

        INTERNAL METHOD AddKey(recordNo AS LONG) AS LOGIC
            IF ! SELF:_Custom
                RETURN FALSE
            ENDIF
            SELF:_saveCurrentKey(recordNo, SELF:_newvalue)
            SELF:_locate(SELF:_newValue:Key, SELF:_keySize, SearchMode.Right, SELF:_rootPage, recordNo)
            VAR page := SELF:Stack:Top:Page
            VAR pos  := SELF:Stack:Top:Pos
            SELF:DoAction(CdxAction.InsertKey(page, pos, SELF:_newValue:Recno, SELF:_newValue:Key))
            RETURN TRUE

        INTERNAL METHOD SetCustom() AS LOGIC
            LOCAL lOld := SELF:_Custom AS LOGIC
            SELF:Header:Options |= CdxOptions.Custom
            SELF:_Custom := TRUE
            RETURN lOld

        INTERNAL METHOD DeleteKey(recordNo AS LONG) AS LOGIC
            IF ! SELF:_Custom
                RETURN FALSE
            ENDIF
            SELF:_saveCurrentKey(recordNo, SELF:_currentValue)
            VAR recno := SELF:_goRecord(SELF:_currentValue:Key, SELF:_keySize, recordNo)
            IF recno == recordNo
                VAR page := SELF:Stack:Top:Page
                VAR pos  := SELF:Stack:Top:Pos
                SELF:DoAction(CdxAction.DeleteKey(page, pos))
                RETURN TRUE
            ENDIF
            RETURN FALSE

        PRIVATE METHOD _keyUpdate(recordNo AS LONG , lNewRecord AS LOGIC ) AS LOGIC
            TRY
                IF SELF:Shared
                    SELF:XLock()
                ENDIF
                //? System.Threading.Thread.CurrentThread.ManagedThreadId:ToString(), "Keyupdate", recordNo
                SELF:_saveCurrentKey(recordNo, SELF:_newvalue)
                IF lNewRecord .AND. ! _newvalue:ForCond
                    // New record and it does not meet the for condition, so no need to update or delete anything
                    SELF:_newValue:CopyTo(SELF:_currentValue)
                    RETURN TRUE
                ENDIF
                LOCAL changed := FALSE AS LOGIC
                changed := SELF:_newValue:ForCond != SELF:_currentValue:ForCond
                IF !lNewRecord
                    // find and delete existing key
                    IF ! changed
                        changed := SELF:__Compare(SELF:_newValue:Key, SELF:_currentValue:Key, SELF:_keySize) != 0
                    ENDIF
                    IF changed
                        SELF:Stack:Clear()
                    ENDIF
                    IF _currentValue:ForCond
                        VAR recno := SELF:_goRecord(SELF:_currentValue:Key, SELF:_keySize, recordNo)
                        IF ! SELF:Stack:Empty  .OR. recno  != 0
                            IF changed .AND. _currentValue:ForCond .AND. recno == recordNo
                                VAR page := SELF:Stack:Top:Page
                                VAR pos  := SELF:Stack:Top:Pos
                                SELF:DoAction(CdxAction.DeleteKey(page, pos))
                            ENDIF
                        ELSE
                            IF !SELF:Unique .AND. !SELF:_Conditional .AND. !SELF:Custom
                                // do not throw an error but ignore the fact that the record was missing
                                //SELF:_oRdd:_dbfError( SubCodes.ERDD_KEY_NOT_FOUND, GenCode.EG_DATATYPE,SELF:fileName)
                                NOP
                            ENDIF
                        ENDIF
                    ENDIF
                ENDIF
                IF (lNewRecord .OR. changed) .AND. _newvalue:ForCond .AND. ! SELF:Custom
                    // new record or changed record, so insert the new key in the tree
                    SELF:ClearStack()
                    IF SELF:Unique
                        IF SELF:_locate(SELF:_newValue:Key, SELF:_keySize, SearchMode.Left, SELF:_rootPage,recordNo)  == 0
                            VAR page := SELF:Stack:Top:Page
                            VAR pos  := SELF:Stack:Top:Pos
                            SELF:DoAction(CdxAction.InsertKey(page, pos, SELF:_newValue:Recno, SELF:_newValue:Key))
                        ELSE
                            SELF:ClearStack()
                        ENDIF
                    ELSE
                        SELF:_locate(SELF:_newValue:Key, SELF:_keySize, SearchMode.Right, SELF:_rootPage,recordNo)
                        IF !SELF:Stack:Empty
                            VAR page := SELF:Stack:Top:Page
                            VAR pos  := SELF:Stack:Top:Pos
                            SELF:DoAction(CdxAction.InsertKey(page, pos, SELF:_newValue:Recno, SELF:_newValue:Key))
                        ELSE
                            RETURN FALSE
                        ENDIF
                    ENDIF
                    SELF:ClearStack()
                    SELF:_Hot := TRUE
                ENDIF
                SELF:_newValue:CopyTo(SELF:_currentValue)
                RETURN TRUE
            FINALLY
                IF SELF:Shared
                    SELF:UnLock()
                ENDIF
            END TRY
            
        PRIVATE METHOD _getLeaf AS CdxLeafPage
            VAR page    := SELF:CurrentStack:Page
            IF page IS CdxLeafPage VAR leaf
                RETURN leaf
            ENDIF
            IF page:NumKeys > 0
                VAR pageNo  := page:LastNode:ChildPageNo
                page    := (CdxTreePage) SELF:OrderBag:GetPage(pageNo, _keySize, SELF)
                IF page IS CdxLeafPage VAR leaf
                    SELF:PushPage(page, 0)
                    RETURN leaf
                ENDIF
            ENDIF
            RETURN NULL
            
    END CLASS
    
END NAMESPACE



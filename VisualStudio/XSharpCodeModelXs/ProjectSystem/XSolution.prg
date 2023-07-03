//
// Copyright (c) XSharp B.V.  All Rights Reserved.
// Licensed under the Apache License, Version 2.0.
// See License.txt in the project root for license information.
//
USING System.Collections.Concurrent
USING System.Collections.Generic
USING System.IO
USING System.Linq
USING System


BEGIN NAMESPACE XSharpModel
    STATIC CLASS XSolution
    // Fields
    STATIC PRIVATE _orphanedFilesProject := NULL AS XProject
    PUBLIC CONST BuiltInFunctions_prg := "BuiltInFunctions.prg" as STRING
    PUBLIC CONST TempFolderName := "XSharp.Intellisense" as STRING
    STATIC PRIVATE _workDir as STRING
    STATIC PROPERTY TempFolder as string GET _workDir
    STATIC PROPERTY IsOpen as LOGIC GET !String.IsNullOrEmpty(_fileName)

    STATIC PRIVATE _projects AS ConcurrentDictionary<STRING, XProject>
    STATIC PRIVATE _fileName   AS STRING
    STATIC PRIVATE _sqldb      AS STRING
    STATIC PRIVATE _commentTokens AS List<XCommentToken>
    STATIC PROPERTY IsClosing  AS LOGIC AUTO
    STATIC PROPERTY IsShuttingDown  AS LOGIC AUTO

        // OrphanedFiles Project is always open, so at least 1
    STATIC PROPERTY HasProject AS  LOGIC GET _projects:Count > 1
    STATIC PROPERTY FileName AS STRING GET _fileName
    STATIC PROPERTY BuiltInFunctions AS STRING AUTO
    STATIC PROPERTY CommentTokens AS IList<XCommentToken> GET _commentTokens
    STATIC PROPERTY Projects AS IList<XProject> get _projects:Values:ToArray()
    STATIC PROPERTY Logger as ILogger AUTO GET SET := DummyLogger{}

        // Methods
    STATIC CONSTRUCTOR
        _projects := ConcurrentDictionary<STRING, XProject>{StringComparer.OrdinalIgnoreCase}
        IsClosing   := FALSE
        _commentTokens := List < XCommentToken >{}

    STATIC METHOD SetCommentTokens( aTokens AS IList<XCommentToken>) AS VOID
        _commentTokens:Clear()
        _commentTokens:AddRange(aTokens)

    STATIC METHOD WriteOutputMessage(message AS STRING) AS VOID
        IF XSettings.EnableLogging
            XSolution.Logger:Information(message)
        ENDIF
    STATIC METHOD WriteException(ex AS Exception, msg as STRING) AS VOID
        XSolution.Logger:Exception(ex, msg)
        RETURN

    STATIC PRIVATE METHOD _ClearFolder(directory as DirectoryInfo, lDeleteFiles as LOGIC) AS VOID
        if lDeleteFiles
            foreach file as FileInfo in directory:GetFiles()
                _DeleteFile(file:FullName)
            next
        endif
        var subDirectories := directory:GetDirectories()

        // Scan the directories in the current directory and call this method
        // again to go one level into the directory tree
        foreach var subDirectory in subDirectories
            _ClearFolder(subDirectory, true)
            subDirectory:Attributes &= ~FileAttributes.ReadOnly
            subDirectory:Delete()
        next


    STATIC PRIVATE METHOD _DeleteFile(cFileName AS STRING) AS LOGIC
        TRY
            IF System.IO.File.Exists(cFileName)
                System.IO.File.SetAttributes(cFileName, FileAttributes.Normal)
                System.IO.File.Delete(cFileName)
            ENDIF
            RETURN TRUE
        CATCH
            // the file may be in use or so
        END TRY
        RETURN FALSE


    STATIC METHOD CreateBuiltInFunctions(folder as STRING) AS VOID
        TRY
            BuiltInFunctions := Path.Combine(folder, BuiltInFunctions_prg)
            _DeleteFile(BuiltInFunctions)

            _workDir := Path.GetTempPath()
            _workDir := Path.Combine(_workDir,TempFolderName )
            IF !Directory.Exists(_workDir)
                Directory.CreateDirectory(_workDir)
            ELSE
                _ClearFolder(DirectoryInfo{_workDir}, FALSE)
            ENDIF
            BuiltInFunctions := Path.Combine(_workDir, BuiltInFunctions_prg)
            _DeleteFile(BuiltInFunctions)
            System.IO.File.WriteAllText(BuiltInFunctions, XSharpBuiltInFunctions(BuiltInFunctions))
            System.IO.File.SetAttributes(BuiltInFunctions, FileAttributes.ReadOnly)
        CATCH e as Exception
            XSettings.LogException(e,__FUNCTION__)
            BuiltInFunctions := ""
        END TRY

    STATIC METHOD Open(cFile as STRING) AS VOID
        WriteOutputMessage("XModel.Solution.OpenSolution() "+cFile)
        IF IsOpen
            IF String.Compare(_fileName, cFile, TRUE) == 0
                WriteOutputMessage("XModel.Solution.OpenSolution() File was already open"+cFile)
                RETURN
            ENDIF
            Close()
        ENDIF
        _fileName := cFile
        var folder := Path.GetDirectoryName(_fileName)
        folder     := Path.Combine(folder, ".vs")
        IF ! Directory.Exists(folder)
            Directory.CreateDirectory(folder)
        ENDIF
        folder    := Path.Combine(folder, Path.GetFileNameWithoutExtension(_fileName))
        IF ! Directory.Exists(folder)
            Directory.CreateDirectory(folder)
        ENDIF
        CreateBuiltInFunctions(folder)
        _sqldb    := Path.Combine(folder, "X#Model.xsdb")
        XDatabase.CreateOrOpenDatabase(_sqldb)
        VAR dbprojectList := XDatabase.GetProjectFileNames()
        FOREACH var project in _projects:Values
            XDatabase.Read(project)
            ModelWalker.AddProject(project)
            FOREACH VAR dbproject  in dbprojectList
                if String.Compare(dbproject, project:FileName, StringComparison.OrdinalIgnoreCase) == 0
                    dbprojectList:Remove(dbproject)
                    EXIT
                ENDIF
            NEXT
            IF System.IO.File.Exists(BuiltInFunctions)
                project:AddFile(BuiltInFunctions)
            ENDIF
        NEXT
        if dbprojectList:Count > 0
            FOREACH var dbproject in dbprojectList
                XDatabase.DeleteProject(dbproject)
            NEXT
        endif
        ModelWalker.Start()

    STATIC METHOD AddOrphan(fileName as STRING) AS XFile
        OrphanedFilesProject:AddFile(fileName)
        return OrphanedFilesProject:FindXFile(fileName)


    INTERNAL STATIC METHOD Add(project AS XProject) AS LOGIC
        RETURN @@Add(project:Name, project)

    INTERNAL STATIC METHOD Add(projectName AS STRING, project AS XProject) AS LOGIC
        WriteOutputMessage("XModel.Solution.Add() "+projectName+" "+project.FileName)
        IF _projects:ContainsKey(projectName)
            RETURN FALSE
        ENDIF
        VAR lOk := _projects:TryAdd(projectName, project)
        IF lOk .and. IsOpen
            XDatabase.Read(project)
        ENDIF
        RETURN lOk


    STATIC METHOD Close() AS VOID
        IF IsOpen
            WriteOutputMessage("XModel.Solution.CloseSolution()" + _fileName)
            ModelWalker.Stop()
            XDatabase.CloseDatabase(_sqldb)

            FOREACH VAR pair IN _projects:ToArray()
                var project := (XProject) pair:Value
                project:UnLoad()
                project:Close()
            NEXT
            _projects:Clear()
            SystemTypeController.Clear()
            _orphanedFilesProject := NULL
            _fileName  := NULL
        ENDIF

    STATIC METHOD FileClose(fileName AS STRING) AS VOID
        IF FindFile(fileName):Project == _orphanedFilesProject
            _orphanedFilesProject:RemoveFile(fileName)
        ENDIF

    STATIC METHOD FindFile(fileName AS STRING) AS XFile
        FOREACH VAR project IN _projects
            VAR file := project:Value:FindXFile(fileName)
            IF file != NULL
                RETURN file
            ENDIF
        NEXT
        RETURN NULL

    STATIC METHOD FindFullPath(fullPath AS STRING) AS XFile
        FOREACH VAR project IN _projects
            VAR file := project:Value:FindXFile(fullPath)
            IF file != NULL
                RETURN file
            ENDIF
        NEXT
        RETURN NULL

    STATIC METHOD FindProject(projectFile AS STRING) AS XProject
        LOCAL project AS XProject
        projectFile := System.IO.Path.GetFileNameWithoutExtension(projectFile)
        project := NULL
        IF _projects:TryGetValue(projectFile, OUT project) .AND. project != NULL
            RETURN project
        ENDIF
        RETURN NULL

    INTERNAL STATIC METHOD Remove(projectName AS STRING) AS LOGIC
        WriteOutputMessage("XModel.Solution.Remove() "+projectName)
        IF _projects:ContainsKey(projectName)
            VAR result := _projects:TryRemove(projectName, OUT VAR p)
            IF (p != NULL)
                FOREACH otherProject AS XProject IN _projects:Values
                    otherProject:RemoveProjectReference(p:FileName)
                NEXT
            ENDIF
            RETURN result
        ENDIF
        RETURN FALSE

    INTERNAL STATIC METHOD RenameProject(oldName AS STRING, newName AS STRING) AS VOID
         WriteOutputMessage("XModel.Solution.RenameProject() "+oldName+" "+newName)
        IF _projects:ContainsKey(oldName)
            _projects:TryRemove(oldName, OUT VAR project)
            IF project != NULL
                _projects:TryAdd(newName, project)
            ENDIF
        ENDIF

    INTERNAL STATIC METHOD Remove(project AS XProject) AS LOGIC
        IF project != NULL .AND. project:ProjectNode != NULL  .AND. _projects:Count > 0
            RETURN XSolution.Remove(project:Name)
        ENDIF
        RETURN FALSE

    STATIC METHOD WalkFile(fileName AS STRING) AS VOID
        VAR file := FindFile(fileName)
        IF file != NULL
            ModelWalker.FileWalk(file)
        ENDIF
        RETURN

    STATIC METHOD CreateOrphanedFilesProject() AS VOID
        var prj := OrphanedFilesProject{}
        _orphanedFilesProject := XProject{prj}
        VAR projectNode := (OrphanedFilesProject)(_orphanedFilesProject:ProjectNode)
        projectNode:Project := _orphanedFilesProject
        IF _projects:TryAdd(prj:Name, _orphanedFilesProject)
            projectNode:Project:AddAssemblyReference(TYPEOF(STRING):Assembly:Location)
        ENDIF

    STATIC METHOD SetStatusBarText(cText AS STRING) AS VOID
        XSettings.SetStatusBarText(cText)

    STATIC METHOD SetStatusBarProgress(cMessage as STRING, nItem AS LONG, nTotal as LONG) AS VOID
        XSettings.SetStatusBarProgress(cMessage, nItem, nTotal)

    STATIC METHOD SetStatusBarAnimation(onOff AS LOGIC, id AS SHORT) AS VOID
        XSettings.SetStatusBarAnimation(onOff, id)

   STATIC PROPERTY OrphanedFilesProject AS XProject
        GET
            IF _orphanedFilesProject == NULL
                CreateOrphanedFilesProject()
            ENDIF
            RETURN _orphanedFilesProject
        END GET
    END PROPERTY

    END CLASS


    CLASS DummyLogger IMPLEMENTS ILogger

        #region Implement ILogger

        PUBLIC METHOD Information(sMsg AS STRING) AS VOID
            RETURN

        PUBLIC METHOD Debug(sMsg AS STRING) AS VOID
            RETURN

        PUBLIC METHOD Start() AS VOID
            RETURN

        PUBLIC METHOD Stop() AS VOID
            RETURN

        PUBLIC PROPERTY Active AS LOGIC GET FALSE


        PUBLIC METHOD SingleLine() AS VOID
            RETURN

        PUBLIC METHOD DoubleLine() AS VOID
            RETURN
        METHOD Exception (e as Exception, sMsg as STRING) AS VOID
            RETURN
        #endregion
    END CLASS




END NAMESPACE


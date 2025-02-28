/* ****************************************************************************
 *
 * Copyright (c) Microsoft Corporation.
 *
 * This source code is subject to terms and conditions of the Apache License, Version 2.0. A
 * copy of the license can be found in the License.txt file at the root of this distribution.
 *
 * You must not remove this notice, or any other, from this software.
 *
 * ***************************************************************************/

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.VisualStudio;
using Microsoft.VisualStudio.Shell.Interop;
using IServiceProvider = System.IServiceProvider;
using XSharpModel;
using Microsoft.VisualStudio.Shell;

namespace Microsoft.VisualStudio.Project
{
    [CLSCompliant(false)]
    public class SolutionListenerForProjectReferenceUpdate : SolutionListener
    {

        #region ctor
        public SolutionListenerForProjectReferenceUpdate(IServiceProvider serviceProvider)
            : base(serviceProvider)
        {
        }
        #endregion

        #region overridden methods
        /// <summary>
        /// Delete this project from the references of projects of this type, if it is found.
        /// </summary>
        /// <param name="hierarchy"></param>
        /// <param name="removed"></param>
        /// <returns></returns>
        public override int OnBeforeCloseProject(IVsHierarchy hierarchy, int removed)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            if (removed != 0)
            {
                List<ProjectReferenceNode> projectReferences = this.GetProjectReferencesContainingThisProject(hierarchy);

                foreach(ProjectReferenceNode projectReference in projectReferences)
                {
                    projectReference.Remove(false);
                    // Set back the remove state on the project refererence. The reason why we are doing this is that the OnBeforeUnloadProject immedaitely calls
                    // OnBeforeCloseProject, thus we would be deleting references when we should not. Unload should not remove references.
                    projectReference.CanRemoveReference = true;
                }
            }

            return VSConstants.S_OK;
        }


        /// <summary>
        /// Needs to update the dangling reference on projects that contain this hierarchy as project reference.
        /// </summary>
        /// <param name="stubHierarchy"></param>
        /// <param name="realHierarchy"></param>
        /// <returns></returns>
        public override int OnAfterLoadProject(IVsHierarchy stubHierarchy, IVsHierarchy realHierarchy)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            List<ProjectReferenceNode> projectReferences = this.GetProjectReferencesContainingThisProject(realHierarchy);

            // Refersh the project reference node. That should trigger the drawing of the normal project reference icon.
            foreach(ProjectReferenceNode projectReference in projectReferences)
            {
                projectReference.CanRemoveReference = true;

                projectReference.OnInvalidateItems(projectReference.Parent);
            }

            return VSConstants.S_OK;
        }


        public override int OnAfterRenameProject(IVsHierarchy hierarchy)
        {
            if(hierarchy == null)
            {
                return VSConstants.E_INVALIDARG;
            }
            ThreadHelper.ThrowIfNotOnUIThread();

            try
            {
                List<ProjectReferenceNode> projectReferences = this.GetProjectReferencesContainingThisProject(hierarchy);

                // Collect data that is needed to initialize the new project reference node.
                string projectRef;
                ErrorHandler.ThrowOnFailure(this.Solution.GetProjrefOfProject(hierarchy, out projectRef));

                object nameAsObject;
                ErrorHandler.ThrowOnFailure(hierarchy.GetProperty(VSConstants.VSITEMID_ROOT, (int)__VSHPROPID.VSHPROPID_Name, out nameAsObject));
                string projectName = (string)nameAsObject;

                string projectPath = String.Empty;

                IVsProject3 project = hierarchy as IVsProject3;

                if(project != null)
                {
                    ErrorHandler.ThrowOnFailure(project.GetMkDocument(VSConstants.VSITEMID_ROOT, out projectPath));
                    projectPath = Path.GetDirectoryName(projectPath);
                }

                // Remove and re add the node.
                foreach(ProjectReferenceNode projectReference in projectReferences)
                {
                    ProjectNode projectMgr = projectReference.ProjectMgr;
                    IReferenceContainer refContainer = projectMgr.GetReferenceContainer();
                    projectReference.Remove(false);

                    VSCOMPONENTSELECTORDATA selectorData = new VSCOMPONENTSELECTORDATA();
                    selectorData.type = VSCOMPONENTTYPE.VSCOMPONENTTYPE_Project;
                    selectorData.bstrTitle = projectName;
                    selectorData.bstrFile = projectPath;
                    selectorData.bstrProjRef = projectRef;
                    refContainer.AddReferenceFromSelectorData(selectorData);
                }
            }
            catch(COMException e)
            {
                XSettings.LogException(e, "OnAfterRenameProject");
                return e.ErrorCode;
            }

            return VSConstants.S_OK;
        }


        public override int OnBeforeUnloadProject(IVsHierarchy realHierarchy, IVsHierarchy stubHierarchy)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            List<ProjectReferenceNode> projectReferences = this.GetProjectReferencesContainingThisProject(realHierarchy);

            // Refresh the project reference node. That should trigger the drawing of the dangling project reference icon.
            foreach(ProjectReferenceNode projectReference in projectReferences)
            {
                projectReference.IsNodeValid = true;
                projectReference.OnInvalidateItems(projectReference.Parent);
                projectReference.CanRemoveReference = false;
                projectReference.IsNodeValid = false;
                projectReference.DropReferencedProjectCache();
            }

            return VSConstants.S_OK;

        }

        #endregion

        #region helper methods
        private List<ProjectReferenceNode> GetProjectReferencesContainingThisProject(IVsHierarchy inputHierarchy)
        {
            List<ProjectReferenceNode> projectReferences = new List<ProjectReferenceNode>();
            if(this.Solution == null || inputHierarchy == null)
            {
                return projectReferences;
            }

            uint flags = (uint)(__VSENUMPROJFLAGS.EPF_ALLPROJECTS | __VSENUMPROJFLAGS.EPF_LOADEDINSOLUTION);
            Guid enumOnlyThisType = Guid.Empty;
            IEnumHierarchies enumHierarchies = null;
            ThreadHelper.ThrowIfNotOnUIThread();

            ErrorHandler.ThrowOnFailure(this.Solution.GetProjectEnum(flags, ref enumOnlyThisType, out enumHierarchies));
            Debug.Assert(enumHierarchies != null, "Could not get list of hierarchies in solution");

            IVsHierarchy[] hierarchies = new IVsHierarchy[1];
            uint fetched;
            int returnValue = VSConstants.S_OK;
            do
            {
                returnValue = enumHierarchies.Next(1, hierarchies, out fetched);
                Debug.Assert(fetched <= 1, "We asked one project to be fetched VSCore gave more than one. We cannot handle that");
                if(returnValue == VSConstants.S_OK && fetched == 1)
                {
                    IVsHierarchy hierarchy = hierarchies[0];
                    Debug.Assert(hierarchy != null, "Could not retrieve a hierarchy");
                    IReferenceContainerProvider provider = hierarchy as IReferenceContainerProvider;
                    if(provider != null)
                    {
                        IReferenceContainer referenceContainer = provider.GetReferenceContainer();

                        Debug.Assert(referenceContainer != null, "Could not found the References virtual node");
                        ProjectReferenceNode projectReferenceNode = GetProjectReferenceOnNodeForHierarchy(referenceContainer.EnumReferences(), inputHierarchy);
                        if(projectReferenceNode != null)
                        {
                            projectReferences.Add(projectReferenceNode);
                        }
                    }
                }
            } while(returnValue == VSConstants.S_OK && fetched == 1);

            return projectReferences;
        }

        private static ProjectReferenceNode GetProjectReferenceOnNodeForHierarchy(IList<ReferenceNode> references, IVsHierarchy inputHierarchy)
        {
            if(references == null)
            {
                return null;
            }
            ThreadHelper.ThrowIfNotOnUIThread();

            Guid projectGuid;
            inputHierarchy.GetGuidProperty(VSConstants.VSITEMID_ROOT, (int)__VSHPROPID.VSHPROPID_ProjectIDGuid, out projectGuid);

            string canonicalName;
            ThreadHelper.ThrowIfNotOnUIThread();
            inputHierarchy.GetCanonicalName(VSConstants.VSITEMID_ROOT, out canonicalName);
            foreach(ReferenceNode refNode in references)
            {
                ProjectReferenceNode projRefNode = refNode as ProjectReferenceNode;
                if(projRefNode != null)
                {
                    if(projRefNode.ReferencedProjectGuid == projectGuid)
                    {
                        return projRefNode;
                    }

                    // Try with canonical names, if the project that is removed is an unloaded project than the above criteria will not pass.
                    if(!String.IsNullOrEmpty(projRefNode.Url) && NativeMethods.IsSamePath(projRefNode.Url, canonicalName))
                    {
                        return projRefNode;
                    }
                }
            }

            return null;

        }
        #endregion
    }
}

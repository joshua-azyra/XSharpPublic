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

using Microsoft.VisualStudio.OLE.Interop;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using XSharpModel;
using MSBuild = Microsoft.Build.Evaluation;
using MSBuildConstruction = Microsoft.Build.Construction;


namespace Microsoft.VisualStudio.Project
{
    public struct ConfigCanonicalName
    {
        private static readonly StringComparer CMP = StringComparer.OrdinalIgnoreCase;
        private readonly string myConfigName;
        private readonly string myPlatform;

        public ConfigCanonicalName(string configName, string platform)
        {
            myConfigName = configName;
            if (CMP.Equals(platform, ProjectConfig.AnyCPU))
                myPlatform = ProjectConfig.Any_CPU;
            else
                myPlatform = platform;
        }

        public ConfigCanonicalName(string configCanonicalName)
        {
            string platform;
            TrySplitConfigurationCanonicalName(configCanonicalName, out myConfigName, out platform);
            if (CMP.Equals(platform, ProjectConfig.AnyCPU))
                myPlatform = ProjectConfig.Any_CPU;
            else
                myPlatform = platform;
        }

        public string ConfigName { get { return myConfigName != null ? myConfigName : String.Empty; } }
        public string Platform { get { return myPlatform != null ? myPlatform : String.Empty; } }

        public bool MatchesPlatform(string platform)
        {
            return CMP.Equals(platform, myPlatform);
        }

        public bool MatchesConfigName(string configName)
        {
            return CMP.Equals(configName, myConfigName);
        }

        public string MSBuildPlatform
        {
            get
            {
                if (CMP.Equals(myPlatform, ProjectConfig.Any_CPU))
                    return ProjectConfig.AnyCPU;
                else
                    return myPlatform != null ? myPlatform : String.Empty;
            }
        }

        public string PlatformTarget
        {
            get { return MSBuildPlatform; }
        }

        public override string ToString()
        {
            if (String.IsNullOrEmpty(myPlatform)) return myConfigName;
            return String.Format("{0}|{1}", myConfigName, myPlatform);
        }

        public string ToMSBuildCondition()
        {
            if (String.IsNullOrEmpty(myPlatform))
            {
                return String.Format(CultureInfo.InvariantCulture, " '$(Configuration)' == '{0}' ", myConfigName);
            }
            else
            {
                return String.Format(CultureInfo.InvariantCulture, " '$(Configuration)|$(Platform)' == '{0}|{1}' ", myConfigName, this.MSBuildPlatform);
            }
        }

        public override int GetHashCode()
        {
            return CMP.GetHashCode(ToString());
        }

        public bool Equals(ConfigCanonicalName other)
        {
            return CMP.Equals(myConfigName, other.myConfigName) && CMP.Equals(myPlatform, other.myPlatform);
        }

        public override bool Equals(object obj)
        {
            if (!(obj is ConfigCanonicalName)) return false;
            return Equals((ConfigCanonicalName)obj);
        }

        public static bool operator ==(ConfigCanonicalName left, ConfigCanonicalName right)
        {
            return left.Equals(right);
        }
        public static bool operator !=(ConfigCanonicalName left, ConfigCanonicalName right)
        {
            return !left.Equals(right);
        }

        /// <summary>
        /// Splits the canonical configuration name into platform and configuration name.
        /// </summary>
        /// <param name="canonicalName">The canonicalName name.</param>
        /// <param name="configName">The name of the configuration.</param>
        /// <param name="platformName">The name of the platform.</param>
        /// <returns>true if successfull.</returns>
        /*internal, but public for FSharp.Project.dll*/
        private static bool TrySplitConfigurationCanonicalName(string canonicalName, out string configName, out string platformName)
        {
            // TODO rationalize this code with callers and ProjectNode.OnHandleConfigurationRelatedGlobalProperties, ProjectNode.TellMSBuildCurrentSolutionConfiguration, etc
            configName = String.Empty;
            platformName = String.Empty;

            if (String.IsNullOrEmpty(canonicalName))
            {
                return false;
            }

            string[] splittedCanonicalName = canonicalName.Split(new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries);

            if (splittedCanonicalName == null || (splittedCanonicalName.Length != 1 && splittedCanonicalName.Length != 2))
            {
                return false;
            }

            configName = splittedCanonicalName[0];
            if (splittedCanonicalName.Length == 2)
            {
                platformName = splittedCanonicalName[1];
            }

            return true;
        }

        public static ConfigCanonicalName OfCondition(string condition)
        {
            const string confOnly = "'$(Configuration)'";
            const string confAndPlatform = "'$(Configuration)|$(Platform)'";
            condition = condition.Trim();
            if (condition.StartsWith(confOnly, StringComparison.Ordinal) || condition.StartsWith(confAndPlatform, StringComparison.Ordinal))
            {
                var eqeqIdx = condition.IndexOf("==", StringComparison.Ordinal);
                if (eqeqIdx < 0) return new ConfigCanonicalName();
                var condTarget = condition.Substring(eqeqIdx + 2).Trim(' ');
                if (condTarget.StartsWith("'", StringComparison.Ordinal)) condTarget = condTarget.Substring(1);
                if (condTarget.EndsWith("'", StringComparison.Ordinal)) condTarget = condTarget.Substring(0, condTarget.Length - 1);
                // In confOnly case condTarget now contains "ConfName"
                // In confInPlatformCase condTarget now contains "ConfName|Platform"
                // ConfigCanonicalName constructor is ok with both
                return new ConfigCanonicalName(condTarget.Trim());
            }
            return new ConfigCanonicalName();
        }
    }

    [CLSCompliant(false), ComVisible(true)]
    public partial class ProjectConfig :
        IVsProjectCfg2,
        IVsProjectFlavorCfg,
        ISpecifyPropertyPages,
        IVsSpecifyProjectDesignerPages,
        IVsCfgBrowseObject
    {
        #region constants
        internal const string Debug = "Debug";
        internal const string Release = "Release";
        internal const string AnyCPU = "AnyCPU";
        internal const string Any_CPU = "Any CPU";
        #endregion

        #region fields
        private ProjectNode project;
        private ConfigCanonicalName configCanonicalName;
        private DateTime lastCache;
        private string projectAssemblyNameCache; // null means invalid
        private MSBuild.Project evaluatedProject = null;
        private List<OutputGroup> outputGroups;
        private IProjectConfigProperties configurationProperties;
        private IVsProjectFlavorCfg flavoredCfg = null;
        private BuildableProjectConfig buildableCfg = null;
        #endregion

        #region properties
        public ProjectNode ProjectMgr
        {
            get
            {
                return this.project;
            }
        }

        public string ConfigName
        {
            get
            {
                return this.configCanonicalName.ConfigName;
            }
            set
            {
                this.configCanonicalName = new ConfigCanonicalName(value, this.configCanonicalName.Platform);
                this.projectAssemblyNameCache = null;
            }
        }

        public ConfigCanonicalName ConfigCanonicalName
        {
            get
            {
                return this.configCanonicalName;
            }
        }

        // Debug property page properties
        public string StartURL
        {
            get
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                return GetConfigurationProperty(ProjectFileConstants.StartURL, false);
            }
            set
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                SetConfigurationProperty(ProjectFileConstants.StartURL, value);
            }
        }

        public string StartArguments
        {
            get
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                return GetConfigurationProperty(ProjectFileConstants.StartArguments, false);
            }
            set
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                SetConfigurationProperty(ProjectFileConstants.StartArguments, value);
            }
        }

        public string StartWorkingDirectory
        {
            get
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                return GetConfigurationProperty(ProjectFileConstants.StartWorkingDirectory, false);
            }
            set
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                SetConfigurationProperty(ProjectFileConstants.StartWorkingDirectory, value);
            }
        }

        public string StartProgram
        {
            get
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                return GetConfigurationProperty(ProjectFileConstants.StartProgram, false);
            }
            set
            {
                ThreadHelper.ThrowIfNotOnUIThread();
                SetConfigurationProperty(ProjectFileConstants.StartProgram, value);
            }
        }

        public int StartAction
        {
            get
            {
                ThreadHelper.ThrowIfNotOnUIThread();

                string startAction = GetConfigurationProperty(ProjectFileConstants.StartAction, false);

                if ("Program" == startAction)
                    return 1;
                else if ("URL" == startAction)
                    return 2;
                else // "Project"
                    return 0;
            }
            set
            {
                string startAction = "";

                switch (value)
                {
                    case 0:
                        startAction = "Project";
                        break;
                    case 1:
                        startAction = "Program";
                        break;
                    case 2:
                        startAction = "URL";
                        break;
                    default:
                        throw new ArgumentException("Invalid StartAction value");
                }
                ThreadHelper.ThrowIfNotOnUIThread();
                SetConfigurationProperty(ProjectFileConstants.StartAction, startAction);
            }
        }

        public virtual string Condition
        {
            get
            {
                return String.Format(CultureInfo.InvariantCulture, ConfigProvider.configString, this.ConfigName);
            }
        }

        public virtual object ConfigurationProperties
        {
            get
            {
                if (this.configurationProperties == null)
                {
                    this.configurationProperties = new ProjectConfigProperties(this);
                }
                return this.configurationProperties;
            }
        }

        protected IList<OutputGroup> OutputGroups
        {
            get
            {
                if (null == this.outputGroups)
                {
                    // Initialize output groups
                    this.outputGroups = new List<OutputGroup>();

                    // Get the list of group names from the project.
                    // The main reason we get it from the project is to make it easier for someone to modify
                    // it by simply overriding that method and providing the correct MSBuild target(s).
                    IList<KeyValuePair<string, string>> groupNames = project.GetOutputGroupNames();

                    if (groupNames != null)
                    {
                        // Populate the output array
                        foreach (KeyValuePair<string, string> group in groupNames)
                        {
                            OutputGroup outputGroup = CreateOutputGroup(project, group);
                            this.outputGroups.Add(outputGroup);
                        }
                    }

                }
                return this.outputGroups;
            }
        }
        #endregion

        #region ctors
        internal ProjectConfig(ProjectNode project, ConfigCanonicalName configName)
        {
            this.project = project;
            this.configCanonicalName = configName;
            this.lastCache = DateTime.MinValue;
            ThreadHelper.ThrowIfNotOnUIThread();

            // Because the project can be aggregated by a flavor, we need to make sure
            // we get the outer most implementation of that interface (hence: project --> IUnknown --> Interface)
            IntPtr projectUnknown = Marshal.GetIUnknownForObject(this.ProjectMgr);
            try
            {
                IVsProjectFlavorCfgProvider flavorCfgProvider = (IVsProjectFlavorCfgProvider)Marshal.GetTypedObjectForIUnknown(projectUnknown, typeof(IVsProjectFlavorCfgProvider));
                ErrorHandler.ThrowOnFailure(flavorCfgProvider.CreateProjectFlavorCfg(this, out flavoredCfg));
                if (flavoredCfg == null)
                    throw new COMException();
            }
            finally
            {
                if (projectUnknown != IntPtr.Zero)
                    Marshal.Release(projectUnknown);
            }
            // if the flavored object support XML fragment, initialize it
            IPersistXMLFragment persistXML = flavoredCfg as IPersistXMLFragment;
            if (null != persistXML)
            {
                this.project.LoadXmlFragment(persistXML, this.DisplayName);
            }
        }

        internal ProjectConfig(ProjectNode project, string configName, string platformName)
            : this(project, new ConfigCanonicalName(configName, platformName))
        {
            ThreadHelper.ThrowIfNotOnUIThread();

        }
        #endregion

        #region methods
        protected internal virtual OutputGroup CreateOutputGroup(ProjectNode project, KeyValuePair<string, string> group)
        {
            OutputGroup outputGroup = new OutputGroup(group.Key, group.Value, project, this);
            return outputGroup;
        }

        public void PrepareBuild(bool clean)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            project.PrepareBuild(this.configCanonicalName, clean);
        }

        public virtual string GetConfigurationProperty(string propertyName, bool resetCache)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            MSBuild.ProjectProperty property = GetMsBuildProperty(propertyName, resetCache);

            if (property == null)
                return null;

            return property.EvaluatedValue;
        }
        protected string GetProjectAssemblyName()
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            if (this.lastCache < this.project.LastModifiedTime || this.projectAssemblyNameCache == null)
            {
                this.lastCache = this.project.LastModifiedTime;
                this.projectAssemblyNameCache = this.project.GetAssemblyName(this.configCanonicalName);
            }
            return this.projectAssemblyNameCache;
        }

        public virtual string GetUnevaluatedConfigurationProperty(string propertyName)
        {
            string result;
            ThreadHelper.ThrowIfNotOnUIThread();
            // Get properties for current configuration from project file and cache it
            this.project.SetConfiguration(this.configCanonicalName);
            this.project.BuildProject.ReevaluateIfNecessary();
            result = this.project.GetProjectPropertyUnevaluated(propertyName);

            // Restore configuration
            project.SetCurrentConfiguration();
            // return property asked for
            return result;
        }


        public virtual void SetConfigurationProperty(string propertyName, string propertyValue)
        {
            if (!this.project.QueryEditProjectFile(false))
            {
                throw Marshal.GetExceptionForHR(VSConstants.OLE_E_PROMPTSAVECANCELLED);
            }
            ThreadHelper.ThrowIfNotOnUIThread();

            SetPropertyUnderCondition(propertyName, propertyValue, Condition);

            // property cache will need to be updated
            this.evaluatedProject = null;

            // Signal the output groups that something is changed
            foreach (OutputGroup group in this.OutputGroups)
            {
                group.InvalidateGroup();
            }
            this.project.SetProjectFileDirty(true);

            return;
        }

        /// <summary>
        /// Emulates the behavior of SetProperty(name, value, condition) on the old MSBuild object model.
        /// This finds a property group with the specified condition (or creates one if necessary) then sets the property in there.
        /// </summary>
        private void SetPropertyUnderCondition(string propertyName, string propertyValue, string condition)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            this.EnsureCache();

            string conditionTrimmed = (condition == null) ? String.Empty : condition.Trim();

            if (conditionTrimmed.Length == 0)
            {
                evaluatedProject.SetProperty(propertyName, propertyValue);
                return;
            }

            // New OM doesn't have a convenient equivalent for setting a property with a particular property group condition.
            // So do it ourselves.
            var matchingGroups = new List<MSBuildConstruction.ProjectPropertyGroupElement>();

            foreach (MSBuildConstruction.ProjectPropertyGroupElement group in this.evaluatedProject.Xml.PropertyGroups)
            {
                if (String.Equals(group.Condition.Trim(), conditionTrimmed, StringComparison.OrdinalIgnoreCase))
                {
                    matchingGroups.Add(group);
                }
            }

            MSBuildConstruction.ProjectPropertyGroupElement selectedGroup = null;
            if (matchingGroups.Count == 1)
            {
                var props = new List<MSBuildConstruction.ProjectPropertyElement>();
                selectedGroup = matchingGroups[0];
                foreach (MSBuildConstruction.ProjectPropertyElement property in selectedGroup.PropertiesReversed) // If there's dupes, pick the last one so we win
                {
                    if (String.Equals(property.Name, propertyName, StringComparison.OrdinalIgnoreCase) && property.Condition.Length == 0)
                    {
                        props.Add(property);
                    }
                }
                if (props.Count > 0)
                {
                    // remove duplicates
                    for (int i = 0; i < props.Count - 1; i++)
                    {
                        selectedGroup.RemoveChild(props[i]);
                    }
                    selectedGroup.SetProperty(propertyName, propertyValue);
                    return;
                }
            }
            else if (matchingGroups.Count > 1)
            {
                bool written = false;
                foreach (var group in matchingGroups)
                {
                    var props = new List<MSBuildConstruction.ProjectPropertyElement>();
                    foreach (MSBuildConstruction.ProjectPropertyElement property in group.PropertiesReversed)
                    {
                        if (String.Equals(property.Name, propertyName, StringComparison.OrdinalIgnoreCase) &&
                            property.Condition.Length == 0)
                        {
                            props.Add(property);
                        }
                    }
                    if (props.Count > 0)
                    {
                        // remove duplicates
                        for (int i = 0; i < props.Count - 1; i++)
                        {
                            group.RemoveChild(props[i]);
                        }
                        group.SetProperty(propertyName, propertyValue);
                        written = true;
                    }
                }
                if (written)
                    return;
                selectedGroup = matchingGroups[0];
            }
            else
            {
                selectedGroup = this.evaluatedProject.Xml.AddPropertyGroup(); // Adds after last existing PG, else at start of project
                selectedGroup.Condition = condition;
            }
            selectedGroup.AddProperty(propertyName, propertyValue);
        }

        /// <summary>
        /// If flavored, and if the flavor config can be dirty, ask it if it is dirty
        /// </summary>
        /// <param name="storageType">Project file or user file</param>
        /// <returns>0 = not dirty</returns>
        internal int IsFlavorDirty(_PersistStorageType storageType)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            int isDirty = 0;
            if (this.flavoredCfg != null && this.flavoredCfg is IPersistXMLFragment)
            {
                ((IPersistXMLFragment)this.flavoredCfg).IsFragmentDirty((uint)storageType, out isDirty);
            }
            return isDirty;
        }



        /// <summary>
        /// If flavored, ask the flavor if it wants to provide an XML fragment
        /// </summary>
        /// <param name="flavor">Guid of the flavor</param>
        /// <param name="storageType">Project file or user file</param>
        /// <param name="fragment">Fragment that the flavor wants to save</param>
        /// <returns>HRESULT</returns>
        internal int GetXmlFragment(Guid flavor, _PersistStorageType storageType, out string fragment)
        {
            fragment = null;
            ThreadHelper.ThrowIfNotOnUIThread();
            int hr = VSConstants.S_OK;
            if (this.flavoredCfg != null && this.flavoredCfg is IPersistXMLFragment)
            {
                Guid flavorGuid = flavor;
                hr = ((IPersistXMLFragment)this.flavoredCfg).Save(ref flavorGuid, (uint)storageType, out fragment, 1);
            }
            return hr;
        }
        #endregion

        #region IVsSpecifyPropertyPages
        public void GetPages(CAUUID[] pages)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            this.GetCfgPropertyPages(pages);
        }
        #endregion

        #region IVsSpecifyProjectDesignerPages
        /// <summary>
        /// Implementation of the IVsSpecifyProjectDesignerPages. It will return the pages that are configuration dependent.
        /// </summary>
        /// <param name="pages">The pages to return.</param>
        /// <returns>VSConstants.S_OK</returns>
        public virtual int GetProjectDesignerPages(CAUUID[] pages)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            this.GetCfgPropertyPages(pages);
            return VSConstants.S_OK;
        }
        #endregion

        #region IVsCfg methods
        /// <summary>
        /// The display name is a two part item
        /// first part is the config name, 2nd part is the platform name
        /// </summary>
        public virtual int get_DisplayName(out string name)
        {
            name = DisplayName;
            return VSConstants.S_OK;
        }

        private string DisplayName
        {
            get
            {
                return this.configCanonicalName.ToString();
            }
        }
        public virtual int get_IsDebugOnly(out int fDebug)
        {
            fDebug = 0;
            if (this.configCanonicalName.ConfigName == Debug)
            {
                fDebug = 1;
            }
            return VSConstants.S_OK;
        }
        public virtual int get_IsReleaseOnly(out int fRelease)
        {
            CCITracing.TraceCall();
            fRelease = 0;
            if (this.configCanonicalName.ConfigName == Release)
            {
                fRelease = 1;
            }
            return VSConstants.S_OK;
        }
        #endregion

        #region IVsProjectCfg methods
        public virtual int EnumOutputs(out IVsEnumOutputs eo)
        {
            CCITracing.TraceCall();
            eo = null;
            return VSConstants.E_NOTIMPL;
        }

        public virtual int get_BuildableProjectCfg(out IVsBuildableProjectCfg pb)
        {
            CCITracing.TraceCall();
            if (buildableCfg == null)
                buildableCfg = new BuildableProjectConfig(this);
            pb = buildableCfg;
            return VSConstants.S_OK;
        }

        public virtual int get_CanonicalName(out string name)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            return ((IVsCfg)this).get_DisplayName(out name);
        }

        public virtual int get_IsPackaged(out int pkgd)
        {
            CCITracing.TraceCall();
            pkgd = 0;
            return VSConstants.S_OK;
        }

        public virtual int get_IsSpecifyingOutputSupported(out int f)
        {
            CCITracing.TraceCall();
            f = 1;
            return VSConstants.S_OK;
        }

        public virtual int get_Platform(out Guid platform)
        {
            CCITracing.TraceCall();
            platform = Guid.Empty;
            return VSConstants.E_NOTIMPL;
        }

        public virtual int get_ProjectCfgProvider(out IVsProjectCfgProvider p)
        {
            CCITracing.TraceCall();
            p = null;
            ThreadHelper.ThrowIfNotOnUIThread();
            IVsCfgProvider cfgProvider = null;
            this.project.GetCfgProvider(out cfgProvider);
            if (cfgProvider != null)
            {
                p = cfgProvider as IVsProjectCfgProvider;
            }

            return (null == p) ? VSConstants.E_NOTIMPL : VSConstants.S_OK;
        }

        public virtual int get_RootURL(out string root)
        {
            CCITracing.TraceCall();
            root = null;
            return VSConstants.S_OK;
        }

        public virtual int get_TargetCodePage(out uint target)
        {
            CCITracing.TraceCall();
            target = (uint)System.Text.Encoding.Default.CodePage;
            return VSConstants.S_OK;
        }

        public virtual int get_UpdateSequenceNumber(ULARGE_INTEGER[] li)
        {
            if (li == null)
            {
                throw new ArgumentNullException("li");
            }

            CCITracing.TraceCall();
            li[0] = new ULARGE_INTEGER();
            li[0].QuadPart = 0;
            return VSConstants.S_OK;
        }

        public virtual int OpenOutput(string name, out IVsOutput output)
        {
            CCITracing.TraceCall();
            output = null;
            return VSConstants.E_NOTIMPL;
        }
        #endregion



        #region IVsProjectCfg2 Members

        public virtual int OpenOutputGroup(string szCanonicalName, out IVsOutputGroup ppIVsOutputGroup)
        {
            ppIVsOutputGroup = null;
            // Search through our list of groups to find the one they are looking forgroupName
            ThreadHelper.ThrowIfNotOnUIThread();
            foreach (OutputGroup group in OutputGroups)
            {
                string groupName;
                group.get_CanonicalName(out groupName);
                if (String.Compare(groupName, szCanonicalName, StringComparison.OrdinalIgnoreCase) == 0)
                {
                    ppIVsOutputGroup = group;
                    break;
                }
            }
            return (ppIVsOutputGroup != null) ? VSConstants.S_OK : VSConstants.E_FAIL;
        }

        public virtual int OutputsRequireAppRoot(out int pfRequiresAppRoot)
        {
            pfRequiresAppRoot = 0;
            return VSConstants.E_NOTIMPL;
        }

        public virtual int get_CfgType(ref Guid iidCfg, out IntPtr ppCfg)
        {
            // Delegate to the flavored configuration (to enable a flavor to take control)
            // Since we can be asked for Configuration we don't support, avoid throwing and return the HRESULT directly
            ThreadHelper.ThrowIfNotOnUIThread();
            int hr = flavoredCfg.get_CfgType(ref iidCfg, out ppCfg);

            if (ppCfg != IntPtr.Zero)
                return hr;

            IntPtr pUnk = IntPtr.Zero;
            try
            {
                pUnk = Marshal.GetIUnknownForObject(this);
                return Marshal.QueryInterface(pUnk, ref iidCfg, out ppCfg);
            }
            finally
            {
                if (pUnk != IntPtr.Zero) Marshal.Release(pUnk);
            }
        }

        public virtual int get_IsPrivate(out int pfPrivate)
        {
            pfPrivate = 0;
            return VSConstants.S_OK;
        }

        public virtual int get_OutputGroups(uint celt, IVsOutputGroup[] rgpcfg, uint[] pcActual)
        {
            // Are they only asking for the number of groups?
            if (celt == 0)
            {
                if ((null == pcActual) || (0 == pcActual.Length))
                {
                    throw new ArgumentNullException("pcActual");
                }
                pcActual[0] = (uint)OutputGroups.Count;
                return VSConstants.S_OK;
            }

            // Check that the array of output groups is not null
            if ((null == rgpcfg) || (rgpcfg.Length == 0))
            {
                throw new ArgumentNullException("rgpcfg");
            }

            // Fill the array with our output groups
            uint count = 0;
            foreach (OutputGroup group in OutputGroups)
            {
                if (rgpcfg.Length > count && celt > count && group != null)
                {
                    rgpcfg[count] = group;
                    ++count;
                }
            }

            if (pcActual != null && pcActual.Length > 0)
                pcActual[0] = count;

            // If the number asked for does not match the number returned, return S_FALSE
            return (count == celt) ? VSConstants.S_OK : VSConstants.S_FALSE;
        }

        public virtual int get_VirtualRoot(out string pbstrVRoot)
        {
            pbstrVRoot = null;
            return VSConstants.E_NOTIMPL;
        }

        #endregion

        #region IVsCfgBrowseObject
        /// <summary>
        /// Maps back to the configuration corresponding to the browse object.
        /// </summary>
        /// <param name="cfg">The IVsCfg object represented by the browse object</param>
        /// <returns>If the method succeeds, it returns S_OK. If it fails, it returns an error code. </returns>
        public virtual int GetCfg(out IVsCfg cfg)
        {
            cfg = this;
            return VSConstants.S_OK;
        }

        /// <summary>
        /// Maps back to the hierarchy or project item object corresponding to the browse object.
        /// </summary>
        /// <param name="hier">Reference to the hierarchy object.</param>
        /// <param name="itemid">Reference to the project item.</param>
        /// <returns>If the method succeeds, it returns S_OK. If it fails, it returns an error code. </returns>
        public virtual int GetProjectItem(out IVsHierarchy hier, out uint itemid)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            if (this.project == null || this.project.NodeProperties == null)
            {
                throw new InvalidOperationException();
            }
            return this.project.NodeProperties.GetProjectItem(out hier, out itemid);
        }
        #endregion

        #region helper methods

        private void EnsureCache()
        {
            // Get properties for current configuration from project file and cache it
            ThreadHelper.ThrowIfNotOnUIThread();
            this.project.SetConfiguration(configCanonicalName);
            this.evaluatedProject = this.project.BuildProject;
        }

        public MSBuild.ProjectProperty GetMsBuildProperty(string propertyName, bool resetCache)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            if (resetCache || this.evaluatedProject == null)
            {
                this.EnsureCache();
            }

            if (this.evaluatedProject == null)
                throw new Exception("Failed to retrive properties");

            // return property asked for
            return this.evaluatedProject.GetProperty(propertyName);
        }

        /// <summary>
        /// Retrieves the configuration dependent property pages.
        /// </summary>
        /// <param name="pages">The pages to return.</param>
        private void GetCfgPropertyPages(CAUUID[] pages)
        {
            // We do not check whether the supportsProjectDesigner is set to true on the ProjectNode.
            // We rely that the caller knows what to call on us.
            if (pages == null)
            {
                throw new ArgumentNullException("pages");
            }

            if (pages.Length == 0)
            {
                throw new ArgumentException(SR.GetString(SR.InvalidParameter, CultureInfo.CurrentUICulture), "pages");
            }
            ThreadHelper.ThrowIfNotOnUIThread();

            // Retrieve the list of guids from hierarchy properties.
            // Because a flavor could modify that list we must make sure we are calling the outer most implementation of IVsHierarchy
            IVsHierarchy hierarchy = HierarchyNode.GetOuterHierarchy(this.project);
            ErrorHandler.ThrowOnFailure(hierarchy.GetProperty(VSConstants.VSITEMID_ROOT, (int)__VSHPROPID2.VSHPROPID_CfgPropertyPagesCLSIDList, out var variant), new int[] { VSConstants.DISP_E_MEMBERNOTFOUND, VSConstants.E_NOTIMPL });
            var guidsList = (string)variant;

            Guid[] guids = Utilities.GuidsArrayFromSemicolonDelimitedStringOfGuids(guidsList);
            if (guids == null || guids.Length == 0)
            {
                pages[0] = new CAUUID();
                pages[0].cElems = 0;
            }
            else
            {
                pages[0] = PackageUtilities.CreateCAUUIDFromGuidArray(guids);
            }
        }
        #endregion

        #region IVsProjectFlavorCfg Members
        /// <summary>
        /// This is called to let the flavored config let go
        /// of any reference it may still be holding to the base config
        /// </summary>
        /// <returns></returns>
        int IVsProjectFlavorCfg.Close()
        {
            // This is used to release the reference the flavored config is holding
            // on the base config, but in our scenario these 2 are the same object
            // so we have nothing to do here.
            return VSConstants.S_OK;
        }

        /// <summary>
        /// Actual implementation of get_CfgType.
        /// When not flavored or when the flavor delegate to use
        /// we end up creating the requested config if we support it.
        /// </summary>
        /// <param name="iidCfg">IID representing the type of config object we should create</param>
        /// <param name="ppCfg">Config object that the method created</param>
        /// <returns>HRESULT</returns>
        int IVsProjectFlavorCfg.get_CfgType(ref Guid iidCfg, out IntPtr ppCfg)
        {
            ppCfg = IntPtr.Zero;

            ThreadHelper.ThrowIfNotOnUIThread();
            // See if this is an interface we support
            if (iidCfg == typeof(IVsDebuggableProjectCfg).GUID)
                ppCfg = Marshal.GetComInterfaceForObject(this, typeof(IVsDebuggableProjectCfg));
            else if (iidCfg == typeof(IVsBuildableProjectCfg).GUID)
            {
                IVsBuildableProjectCfg buildableConfig;
                this.get_BuildableProjectCfg(out buildableConfig);
                ppCfg = Marshal.GetComInterfaceForObject(buildableConfig, typeof(IVsBuildableProjectCfg));
            }

            // If not supported
            if (ppCfg == IntPtr.Zero)
                return VSConstants.E_NOINTERFACE;

            return VSConstants.S_OK;
        }

        #endregion
    }

    [CLSCompliant(false)]
    [ComVisible(true)]
    public class DebuggableProjectConfig :
        XProjectConfig,
        IVsDebuggableProjectCfg,
        IVsQueryDebuggableProjectCfg
    {
        #region ctors
        public DebuggableProjectConfig(ProjectNode project, ConfigCanonicalName conigName)
            : base(project, conigName)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

        }
        #endregion

        #region IVsDebuggableProjectCfg methods

        private VsDebugTargetInfo GetDebugTargetInfo(uint grfLaunch)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            VsDebugTargetInfo info = new VsDebugTargetInfo();
            info.cbSize = (uint)Marshal.SizeOf(info);
            info.dlo = DEBUG_LAUNCH_OPERATION.DLO_CreateProcess;

            // On first call, reset the cache, following calls will use the cached values
            string property = GetConfigurationProperty("StartAction", true);

            // Set the debug target
            if (0 == System.String.Compare("Program", property, StringComparison.OrdinalIgnoreCase))
            {
                string startProgram = StartProgram;
                if (!String.IsNullOrEmpty(startProgram))
                    info.bstrExe = startProgram;
            }
            else
            // property is either null or "Project"
            // we're ignoring "URL" for now
            {
                string outputType = this.ProjectMgr.GetProjectProperty(ProjectFileConstants.OutputType, false);
                if (0 == String.Compare("library", outputType, StringComparison.OrdinalIgnoreCase))
                    throw new ClassLibraryCannotBeStartedDirectlyException();
                info.bstrExe = this.ProjectMgr.GetOutputAssembly(this.ConfigCanonicalName);
            }


            property = GetConfigurationProperty("StartWorkingDirectory", false);
            if (String.IsNullOrEmpty(property))
            {
                // 3273: aligning with C#
                info.bstrCurDir = Path.GetDirectoryName(this.ProjectMgr.GetOutputAssembly(this.ConfigCanonicalName));
            }
            else
            {
                info.bstrCurDir = property;
            }

            property = GetConfigurationProperty("StartArguments", false);
            if (!String.IsNullOrEmpty(property))
            {
                info.bstrArg = property;
            }

            property = GetConfigurationProperty("RemoteDebugMachine", false);
            if (property != null && property.Length > 0)
            {
                info.bstrRemoteMachine = property;
            }

            info.fSendStdoutToOutputWindow = 0;

            property = GetConfigurationProperty("EnableUnmanagedDebugging", false);
            if (property != null && String.Compare(property, "true", StringComparison.OrdinalIgnoreCase) == 0)
            {
                //Set the unmanaged debugger
                info.clsidCustom = VSConstants.DebugEnginesGuids.ManagedAndNative_guid; // {92EF0900-2251-11D2-B72E-0000F87572EF}
            }
            else
            {
                //Set the managed debugger
                info.clsidCustom = VSConstants.DebugEnginesGuids.ManagedOnly_guid; // {449EC4CC-30D2-4032-9256-EE18EB41B62B}
            }
            info.grfLaunch = grfLaunch;
            bool isConsoleApp = String.Compare("exe",
                this.ProjectMgr.GetProjectProperty(ProjectFileConstants.OutputType, false),
                StringComparison.OrdinalIgnoreCase) == 0;
            bool isRemoteDebug = (info.bstrRemoteMachine != null);
            bool noDebug = ((uint)(((__VSDBGLAUNCHFLAGS)info.grfLaunch) & __VSDBGLAUNCHFLAGS.DBGLAUNCH_NoDebug)) != 0;
            // vswhidbey 382587: Do not use cmd.exe to get "Press any key to continue." when remote debugging
            if (isConsoleApp && noDebug && !isRemoteDebug)
            {
                // VSWhidbey 573404: escape the characters ^<>& so that they are passed to the application rather than interpreted by cmd.exe.
                System.Text.StringBuilder newArg = new System.Text.StringBuilder(info.bstrArg);
                newArg.Replace("^", "^^")
                      .Replace("<", "^<")
                      .Replace(">", "^>")
                      .Replace("&", "^&");
                newArg.Insert(0, "\" ");
                newArg.Insert(0, info.bstrExe);
                newArg.Insert(0, "/c \"\"");
                newArg.Append(" & pause\"");
                string newExe = Path.Combine(Environment.SystemDirectory, "cmd.exe");

                info.bstrArg = newArg.ToString();
                info.bstrExe = newExe;
            }
            return info;
        }

        /// <summary>
        /// Called by the vs shell to start debugging (managed or unmanaged).
        /// Override this method to support other debug engines.
        /// </summary>
        /// <param name="grfLaunch">A flag that determines the conditions under which to start the debugger. For valid grfLaunch values, see __VSDBGLAUNCHFLAGS</param>
        /// <returns>If the method succeeds, it returns S_OK. If it fails, it returns an error code</returns>
        public virtual int DebugLaunch(uint grfLaunch)
        {
            CCITracing.TraceCall();
            ThreadHelper.ThrowIfNotOnUIThread();

            try
            {
                VsDebugTargetInfo info = GetDebugTargetInfo(grfLaunch);
                VsShellUtilities.LaunchDebugger(this.ProjectMgr.Site, info);
            }
            catch (ClassLibraryCannotBeStartedDirectlyException)
            {
                throw;
            }
            catch (Exception e)
            {
                XSettings.LogException(e, "DebugLaunch");
                return Marshal.GetHRForException(e);
            }

            return VSConstants.S_OK;
        }

        /// <summary>
        /// Determines whether the debugger can be launched, given the state of the launch flags.
        /// </summary>
        /// <param name="flags">Flags that determine the conditions under which to launch the debugger.
        /// For valid grfLaunch values, see __VSDBGLAUNCHFLAGS or __VSDBGLAUNCHFLAGS2.</param>
        /// <param name="fCanLaunch">true if the debugger can be launched, otherwise false</param>
        /// <returns>S_OK if the method succeeds, otherwise an error code</returns>
        public virtual int QueryDebugLaunch(uint flags, out int fCanLaunch)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            CCITracing.TraceCall();
            string assembly = GetProjectAssemblyName();
            fCanLaunch = (assembly != null && assembly.ToUpperInvariant().EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) ? 1 : 0;
            if (fCanLaunch == 0)
            {
                string property = GetConfigurationProperty("StartProgram", true);
                fCanLaunch = (property != null && property.Length > 0) ? 1 : 0;
            }
            return VSConstants.S_OK;
        }
        #endregion

        #region IVsQueryDebuggableProjectCfg
        public virtual int QueryDebugTargets(uint grfLaunch, uint cTargets, VsDebugTargetInfo2[] debugTargetInfo, uint[] actualTargets)
        {
            ThreadHelper.ThrowIfNotOnUIThread();
            if (debugTargetInfo == null) // caller only queries for number of targets
            {
                actualTargets[0] = 1;
                return VSConstants.S_OK;
            }
            if (cTargets == 0)
            {
                actualTargets[0] = 1;
                return VSConstants.E_FAIL;
            }

            VsDebugTargetInfo targetInfo;
            try
            {
                targetInfo = GetDebugTargetInfo(grfLaunch);
            }
            catch (ClassLibraryCannotBeStartedDirectlyException)
            {
                actualTargets[0] = 0;
                return VSConstants.S_OK;
            }

            // Copying parameters from VsDebugTargetInfo to VsDebugTargetInfo2.
            // Only relevant fields are copied (that is, those that are set by GetDebugTargetInfo)
            var targetInfo2 = new VsDebugTargetInfo2()
            {
                cbSize = (uint)Marshal.SizeOf(typeof(VsDebugTargetInfo2)),
                bstrArg = targetInfo.bstrArg,
                bstrCurDir = targetInfo.bstrCurDir,
                bstrEnv = targetInfo.bstrEnv,
                bstrOptions = targetInfo.bstrOptions,
                bstrExe = targetInfo.bstrExe,
                bstrPortName = targetInfo.bstrPortName,
                bstrRemoteMachine = targetInfo.bstrRemoteMachine,
#if DEV17
                fSendToOutputWindow = targetInfo.fSendStdoutToOutputWindow != 0,
#else
                fSendToOutputWindow = targetInfo.fSendStdoutToOutputWindow,
#endif
                guidLaunchDebugEngine = targetInfo.clsidCustom,
                LaunchFlags = targetInfo.grfLaunch,
                dlo = (uint)targetInfo.dlo,
            };
            targetInfo2.dwDebugEngineCount = 1;
            // Disposed by caller.
            targetInfo2.pDebugEngines = Marshal.AllocCoTaskMem(Marshal.SizeOf(typeof(Guid)));
            byte[] guidBytes = targetInfo.clsidCustom.ToByteArray();
            Marshal.Copy(guidBytes, 0, targetInfo2.pDebugEngines, guidBytes.Length);

            debugTargetInfo[0] = targetInfo2;
            actualTargets[0] = 1;
            return VSConstants.S_OK;
        }
        #endregion



        public string Platform { get { return this.ConfigCanonicalName.Platform; } }
    }

    public class ClassLibraryCannotBeStartedDirectlyException : COMException
    {
        public ClassLibraryCannotBeStartedDirectlyException() : base(SR.GetString(SR.CannotStartLibraries)) { }
    }

    //=============================================================================
    // NOTE: advises on out of proc build execution to maximize
    // future cross-platform targeting capabilities of the VS tools.

    [CLSCompliant(false)]
    [ComVisible(true)]
    [SuppressMessage("Microsoft.Naming", "CA1704:IdentifiersShouldBeSpelledCorrectly", MessageId = "Buildable")]
    public class BuildableProjectConfig : IVsBuildableProjectCfg
    {
        #region fields
        ProjectConfig config = null;
        EventSinkCollection callbacks = new EventSinkCollection();
        #endregion

        #region ctors
        public BuildableProjectConfig(ProjectConfig config)
        {
            this.config = config;
        }
        #endregion

        #region IVsBuildableProjectCfg methods

        public virtual int AdviseBuildStatusCallback(IVsBuildStatusCallback callback, out uint cookie)
        {
            CCITracing.TraceCall();

            cookie = callbacks.Add(callback);
            return VSConstants.S_OK;
        }

        public virtual int get_ProjectCfg(out IVsProjectCfg p)
        {
            CCITracing.TraceCall();

            p = config;
            return VSConstants.S_OK;
        }

        public virtual int QueryStartBuild(uint options, int[] supported, int[] ready)
        {
            CCITracing.TraceCall();
            if (supported != null && supported.Length > 0)
                supported[0] = 1;
            if (ready != null && ready.Length > 0)
                ready[0] = (this.config.ProjectMgr.BuildInProgress) ? 0 : 1;
            return VSConstants.S_OK;
        }

        public virtual int QueryStartClean(uint options, int[] supported, int[] ready)
        {
            CCITracing.TraceCall();
            ThreadHelper.ThrowIfNotOnUIThread();
            config.PrepareBuild(false);
            if (supported != null && supported.Length > 0)
                supported[0] = 1;
            if (ready != null && ready.Length > 0)
                ready[0] = (this.config.ProjectMgr.BuildInProgress) ? 0 : 1;
            return VSConstants.S_OK;
        }

        public virtual int QueryStartUpToDateCheck(uint options, int[] supported, int[] ready)
        {
            CCITracing.TraceCall();
            ThreadHelper.ThrowIfNotOnUIThread();
            config.PrepareBuild(false);
            if (supported != null && supported.Length > 0)
                supported[0] = 0; // TODO:
            if (ready != null && ready.Length > 0)
                ready[0] = (this.config.ProjectMgr.BuildInProgress) ? 0 : 1;
            return VSConstants.S_OK;
        }

        public virtual int QueryStatus(out int done)
        {
            CCITracing.TraceCall();

            done = (this.config.ProjectMgr.BuildInProgress) ? 0 : 1;
            return VSConstants.S_OK;
        }

        public virtual int StartBuild(IVsOutputWindowPane pane, uint options)
        {
            CCITracing.TraceCall();
            ThreadHelper.ThrowIfNotOnUIThread();
            config.PrepareBuild(false);

            // Current version of MSBuild wish to be called in an STA
            uint flags = VSConstants.VS_BUILDABLEPROJECTCFGOPTS_REBUILD;

            // If we are not asked for a rebuild, then we build the default target (by passing null)
            this.Build(options, pane, ((options & flags) != 0) ? MsBuildTarget.Rebuild : null);

            return VSConstants.S_OK;
        }

        public virtual int StartClean(IVsOutputWindowPane pane, uint options)
        {
            CCITracing.TraceCall();
            ThreadHelper.ThrowIfNotOnUIThread();
            config.PrepareBuild(true);
            // Current version of MSBuild wish to be called in an STA
            this.Build(options, pane, MsBuildTarget.Clean);
            return VSConstants.S_OK;
        }

        public virtual int StartUpToDateCheck(IVsOutputWindowPane pane, uint options)
        {
            CCITracing.TraceCall();

            return VSConstants.E_NOTIMPL;
        }

        public virtual int Stop(int fsync)
        {
            CCITracing.TraceCall();

            return VSConstants.S_OK;
        }

        public virtual int UnadviseBuildStatusCallback(uint cookie)
        {
            CCITracing.TraceCall();


            callbacks.RemoveAt(cookie);
            return VSConstants.S_OK;
        }

        public virtual int Wait(uint ms, int fTickWhenMessageQNotEmpty)
        {
            CCITracing.TraceCall();

            return VSConstants.E_NOTIMPL;
        }
        #endregion

        #region helpers

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
        private bool NotifyBuildBegin()
        {
            int shouldContinue = 1;
            ThreadHelper.ThrowIfNotOnUIThread();

            foreach (IVsBuildStatusCallback cb in callbacks)
            {
                try
                {
                    ErrorHandler.ThrowOnFailure(cb.BuildBegin(ref shouldContinue));
                    if (shouldContinue == 0)
                    {
                        return false;
                    }
                }
                catch (Exception e)
                {
                    // If those who ask for status have bugs in their code it should not prevent the build/notification from happening
                    Debug.Fail(String.Format(CultureInfo.CurrentCulture, SR.GetString(SR.BuildEventError, CultureInfo.CurrentUICulture), e.Message));
                }
            }

            return true;
        }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
        private void NotifyBuildEnd(bool isSuccess)
        {
            int success = (isSuccess ? 1 : 0);
            ThreadHelper.ThrowIfNotOnUIThread();

            foreach (IVsBuildStatusCallback cb in callbacks)
            {
                try
                {
                    ErrorHandler.ThrowOnFailure(cb.BuildEnd(success));
                }
                catch (Exception e)
                {
                    // If those who ask for status have bugs in their code it should not prevent the build/notification from happening
                    Debug.Fail(String.Format(CultureInfo.CurrentCulture, SR.GetString(SR.BuildEventError, CultureInfo.CurrentUICulture), e.Message));
                }
            }
        }

        public void Build(uint options, IVsOutputWindowPane output, string target)
        {
            // We want to refresh the references if we are building with the Build or Rebuild target.
            bool shouldRepaintReferences = false; //  (target == null || target == MsBuildTarget.Build || target == MsBuildTarget.Rebuild);
            ThreadHelper.ThrowIfNotOnUIThread();

            if (!NotifyBuildBegin()) return;

            try
            {
                config.ProjectMgr.StartAsyncBuild(options, this.config.ConfigCanonicalName, output, target, (result, projectInstance) =>
                {
                    this.BuildCoda(new BuildResult(result, projectInstance, null), output, shouldRepaintReferences);
                });
            }
            catch (Exception e)
            {
                XSettings.LogException(e, "Build");
                this.BuildCoda(new BuildResult(MSBuildResult.Failed, null, null), output, shouldRepaintReferences);
                throw;
            }
        }
        private void BuildCoda(BuildResult result, IVsOutputWindowPane output, bool shouldRepaintReferences)
        {
            try
            {
                // Now repaint references if that is needed.
                // We hardly rely here on the fact the ResolveAssemblyReferences target has been run as part of the build.
                // One scenario to think at is when an assembly reference is renamed on disk thus becoming unresolvable,
                // but MsBuild can actually resolve it.
                // Another one if the project was opened only for browsing and now the user chooses to build or rebuild.
                ThreadHelper.ThrowIfNotOnUIThread();
                if (shouldRepaintReferences && result.IsSuccessful)
                {
                    this.RefreshReferences();
                }
            }
            finally
            {
                try
                {
                    ErrorHandler.ThrowOnFailure(output.FlushToTaskList());
                }
                finally
                {
                    NotifyBuildEnd(result.IsSuccessful);
                }
            }
        }

        /// <summary>
        /// Refreshes references and redraws them correctly.
        /// </summary>
        public void RefreshReferences()
        {
            // RvdH Call ResolveAssemblyReferences task once and not for every reference
            var instance = this.config.ProjectMgr.ProjectInstance;
            ThreadHelper.ThrowIfNotOnUIThread();
            this.config.ProjectMgr.DoMSBuildSubmission(BuildKind.Sync, MsBuildTarget.ResolveAssemblyReferences, ref instance, null);

            // Refresh the reference container node for assemblies that could be resolved.

            IReferenceContainer referenceContainer = this.config.ProjectMgr.GetReferenceContainer();
            this.config.ProjectMgr.DoInFixedScope(() =>
            {
                foreach (ReferenceNode referenceNode in referenceContainer.EnumReferences())
                {
                    referenceNode.RefreshReference();
                }
            });
        }
        #endregion
    }
}

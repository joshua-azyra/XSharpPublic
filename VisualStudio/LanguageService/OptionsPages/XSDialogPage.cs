﻿using XSharpModel;
using Microsoft.VisualStudio.Shell;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows.Forms;
#pragma warning disable VSTHRD012 
namespace XSharp.LanguageService.OptionsPages
{
    [ComVisible(true)]
    public class XSDialogPage<T, U> : DialogPage where T: XSUserControl, new() where U : OptionsBase, new()
    {
        #region Properties
        public override object AutomationObject => Options;
        public U Options { get; private set; } = null;
        #endregion
        internal XSDialogPage() : base(ThreadHelper.JoinableTaskContext)
        {
            Options = new U();
        }

        public override void LoadSettingsFromStorage()
        {
            base.LoadSettingsFromStorage();
            if (control != null)
            {
                control.ReadValues(Options);
            }
        }
        public override void SaveSettingsToStorage()
        {
            CreateControl();
            if (control != null)
            {
                control.SaveValues(Options);
            }
            base.SaveSettingsToStorage();
            Options.WriteToSettings();
        }

        private void CreateControl()
        {
            if (control == null)
            {
                control = new T
                {
                    optionPage = this
                };
                control.ReadValues(Options);
            }
        }

        XSUserControl control = null;
        /// <summary>
        /// Set the properties of the page from the Options object
        /// </summary>
        /// <param name="options"></param>
        internal void SetOptions(U options)
        {
            Options = options;
        }
        protected override IWin32Window Window
        {
            get
            {
                CreateControl();
                return control;
            }
        }
    }
}

﻿using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Diagnostics;
using Roslyn.Utilities;

namespace Microsoft.CodeAnalysis.CSharp
{
    public sealed partial class CSharpParseOptions
    {
        public bool ArrayZero { get; private set; }

        public bool DebugEnabled { get; private set; }
        public string DefaultIncludeDir { get; private set; }
        public string WindowsDir { get; private set; }
        public string SystemDir { get; private set; }
        public bool NoStdDef { get; private set; }
        public bool VirtualInstanceMethods { get; private set; }

        public string DefaultNamespace { get; private set; }

        public ImmutableArray<string> IncludePaths { get; private set; } = ImmutableArray.Create<string>();

        public void SetXSharpSpecificOptions(XSharpSpecificCompilationOptions opt)
        {
            if (opt != null)
            {
                ArrayZero = opt.ArrayZero;
                VirtualInstanceMethods = opt.Vo3;
                DefaultNamespace = opt.NameSpace;
                DefaultIncludeDir = opt.DefaultIncludeDir;
                WindowsDir = opt.WindowsDir;
                SystemDir = opt.SystemDir;
                NoStdDef = opt.NoStdDef;
                IncludePaths = opt.IncludePaths.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries).ToImmutableArray();
            }
        }

        public void SetOptions(CSharpCommandLineArguments opt)
        {
            if (opt != null)
            {
                DebugEnabled = opt.EmitPdb;
            }
        }

        public void SetXSharpSpecificOptions(CSharpParseOptions opt)
        {
            ArrayZero = opt.ArrayZero;
            DebugEnabled = opt.DebugEnabled;
            DefaultIncludeDir = opt.DefaultIncludeDir;
            WindowsDir = opt.WindowsDir;
            SystemDir = opt.SystemDir;
            VirtualInstanceMethods = opt.VirtualInstanceMethods;
            DefaultNamespace = opt.DefaultNamespace;
            IncludePaths = opt.IncludePaths;
        }
    }
}
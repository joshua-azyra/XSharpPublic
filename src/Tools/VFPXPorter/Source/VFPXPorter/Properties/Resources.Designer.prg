﻿//------------------------------------------------------------------------------
//  <auto-generated>
//     This code was generated by a tool.
//     Runtime version: 4.0.30319.42000
//     Generator      : XSharp.CodeDomProvider 2.13.2.2
//     Timestamp      : 15/09/2022 19:53:30
//     
//     Changes to this file may cause incorrect behavior and may be lost if
//     the code is regenerated.
//  </auto-generated>
//------------------------------------------------------------------------------
BEGIN NAMESPACE VFPXPorter.Properties
	USING System
	///	<summary>
	///	  A strongly-typed resource class, for looking up localized strings, etc.
	///	</summary>
	//	This class was auto-generated by the StronglyTypedResourceBuilder
	//	class via a tool like ResGen or Visual Studio.
	//	To add or remove a member, edit your .ResX file then rerun ResGen
	//	with the /str option, or rebuild your VS project.
	[global::System.CodeDom.Compiler.GeneratedCodeAttribute("System.Resources.Tools.StronglyTypedResourceBuilder", "17.0.0.0")] ;
	[global::System.Diagnostics.DebuggerNonUserCodeAttribute()] ;
	[global::System.Runtime.CompilerServices.CompilerGeneratedAttribute()] ;
	PUBLIC CLASS Resources
		PRIVATE STATIC resourceMan AS global::System.Resources.ResourceManager
		PRIVATE STATIC resourceCulture AS global::System.Globalization.CultureInfo
		[global::System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1811:AvoidUncalledPrivateCode")] ;
		INTERNAL CONSTRUCTOR() STRICT
		///	<summary>
		///	  Returns the cached ResourceManager instance used by this class.
		///	</summary>
		[global::System.ComponentModel.EditorBrowsableAttribute(global::System.ComponentModel.EditorBrowsableState.Advanced)] ;
		INTERNAL STATIC PROPERTY ResourceManager AS global::System.Resources.ResourceManager
		
			GET
				IF System.Object.ReferenceEquals(resourceMan, NULL)
					LOCAL temp	:=	global::System.Resources.ResourceManager{"VFPXPorter.Properties.Resources", typeof(Resources):Assembly} AS global::System.Resources.ResourceManager
					resourceMan	:=	temp
				ENDIF
				RETURN	resourceMan
			END GET
		END PROPERTY 
		///	<summary>
		///	  Overrides the current thread's CurrentUICulture property for all
		///	  resource lookups using this strongly typed resource class.
		///	</summary>
		[global::System.ComponentModel.EditorBrowsableAttribute(global::System.ComponentModel.EditorBrowsableState.Advanced)] ;
		INTERNAL STATIC PROPERTY Culture AS global::System.Globalization.CultureInfo
		
			GET
				RETURN	resourceCulture
			END GET
		
			SET
				resourceCulture	:=	value
			END SET
		END PROPERTY 
		///	<summary>
		///	  Looks up a localized resource of type System.Drawing.Icon similar to (Icon).
		///	</summary>
		INTERNAL STATIC PROPERTY XSharp AS System.Drawing.Icon
		
			GET
				LOCAL obj	:=	ResourceManager:GetObject("XSharp", resourceCulture) AS System.Object
				RETURN	((System.Drawing.Icon)(obj))
			END GET
		END PROPERTY 
	
	END CLASS 
END NAMESPACE

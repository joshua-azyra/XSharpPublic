﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.  
// Licensed under the Apache License, Version 2.0.  
// See License.txt in the project root for license information.
//
using System.Collections.Generic
using System.Runtime.InteropServices
using System.Diagnostics
using System.Text
using System.Reflection
begin namespace XSharp
	
	
	[DebuggerDisplay( "{DebuggerString(),nq}", Type := "PSZ" ) ] ;
	structure __Psz
		private _value as byte ptr
		static property _NULL_PSZ as __Psz get (__Psz) IntPtr.zero
		private static _pszList as List< IntPtr>

		internal static method RegisterPsz(pszToRegister as PSZ) as void
			if _pszList == null
				_pszList := List<IntPtr>{}
				AppDomain.CurrentDomain:ProcessExit += System.EventHandler{ NULL, @__FreePSZs() }
			endif
			if !_pszList:Contains(pszToRegister:Address)
				_pszList:add(pszToRegister:Address)
			endif
			return
		
		internal static method CreatePsz( cString as string) as psz
				return Psz{cString}
		
		private static method __FreePSZs(o AS OBJECT, args AS EventArgs ) AS VOID
			foreach var pszToFree in _pszList
				try
					MemFree(pszToFree)
				catch
					nop
				end try
			next
			_pszList := NULL
		
		constructor (s as string)
			// this constructor has a memory leak
			// there is no garbage collection for structures
			// to free the memory we need to call MemFree on the pointer
			_value := String2Mem(s)
			RegisterPsz(_value)
			return
		
		constructor (p as IntPtr)
			_value := p
		
		override method ToString() as string
			return Mem2String( _value, Length ) 
		
		method DebuggerString() as string
			return iif( _value == null_ptr, "NULL_PSZ", e"\""+ tostring() +  e"\"" )
		
		
		method equals( p as Psz ) as logic
			
			local ret := false as logic
			if _value == p:_value
				ret := true
			elseif _value != null && p:_value != null
				ret := String.CompareOrdinal( ToString(), p:ToString() ) == 0
			endif
			return ret   
		
		method LessThan( p as Psz ) as logic
			// todo: should this follow nation rules ?
			local ret := false as logic
			if _value == p:_value
				ret := false
			elseif _value != null && p:_value != null
				ret := String.CompareOrdinal( ToString(), p:ToString() ) < 0
			endif
			return ret       
		
		method GreaterThan( p as Psz ) as logic
			local ret := false as logic
			// todo: should this follow nation rules ?
			if _value == p:_value
				ret := false
			elseif _value != null && p:_value != null
				ret := String.CompareOrdinal( ToString(), p:ToString() ) > 0
			endif
			return ret     
		
		
		override method Equals( o as object ) as logic
			local ret := false as logic
			
			if o is Psz
				ret := self:Equals( (Psz) o )
			endif
			
		return ret
		
		override method GetHashCode() as int
			return (int) _value
		
		method Free() as void
			if _value != null_ptr
				MemFree( _value )
				_value := null_ptr
			endif
			return
		
		property Length as dword
			get
				local len as dword
				len := 0
				if _value != null_ptr
					do while _value[len+1] != 0
						len++
					enddo
				endif
				return len 
			end get
		end property
		
		property IsEmpty as logic
			get
				local empty := true as logic
				local b as byte
				local x := 1 as int
				if _value != null_ptr
					b := _value[x]
					do while b != 0 .and. empty
						switch b
							case 32
							case 13
							case 10
							case 9
								nop
							otherwise
								empty := false
						end switch
						x += 1
						b := _value[x]
					enddo
				endif
				return empty
				
				
			end get
		end property
		property IsNull as logic get _value == null
		property Address as IntPtr get _value
	
		property Item[index as int] as byte
			get
				return _value[index]
			end get
			set
				_value[index] := value
			end set
		end property
		
		#region operator methods
			// binary
			operator +( lhs as Psz, rhs as Psz ) as Psz
				return Psz{ lhs:ToString() + rhs:ToString() }
			
			operator +( lhs as Psz, rhs as string ) as Psz
				return Psz{ lhs:ToString() + rhs }
			
			operator +( lhs as string, rhs as Psz ) as string
				return lhs + rhs:ToString()
			
			operator -( lhs as Psz, rhs as Psz ) as Psz
				local l   := lhs:ToString() as string
				local r   := rhs:ToString() as string
				return Psz{ String.Concat( l:TrimEnd(), r:TrimEnd() ):PadRight( l:Length + r:Length ) }
			
			
			operator -( lhs as Psz, rhs as string ) as Psz
				local l   := lhs:ToString() as string
				return Psz{ String.Concat( l:TrimEnd(), rhs:TrimEnd() ):PadRight( l:Length + rhs:Length ) }
			
			operator -( lhs as string, rhs as Psz ) as string
				local r   := rhs:ToString() as string
				return String.Concat( lhs:TrimEnd(), r:TrimEnd() ):PadRight( lhs:Length + r:Length )
			
			// Comparison Operators
			operator ==( lhs as Psz, rhs as Psz ) as logic
				return lhs:Equals( rhs )
			
			operator !=( lhs as Psz, rhs as Psz ) as logic
				return ! lhs:Equals( rhs )
			
			operator <( lhs as Psz, rhs as Psz ) as logic
				return lhs:LessThan( rhs )
			
			operator <=( lhs as Psz, rhs as Psz ) as logic
				return ! lhs:GreaterThan( rhs )
			
			operator >( lhs as Psz, rhs as Psz ) as logic
				return lhs:GreaterThan( rhs )
			
			operator >=( lhs as Psz, rhs as Psz ) as logic
				return ! lhs:LessThan( rhs )
			
			// Conversion Operators - To PSZ...  
			
			// PTR -> PSZ
			operator implicit( p as ptr ) as Psz
				return Psz{ (IntPtr) p }
			
			// BYTE PTR -> PSZ
			operator implicit( p as byte ptr ) as Psz
				return Psz{ (IntPtr) p }
			
			// SByte PTR -> PSZ
			operator implicit( p as SByte ptr ) as Psz
				return Psz{ (IntPtr) p }
			
			// IntPtr -> PSZ
			operator implicit( p as IntPtr ) as Psz
				return Psz{ p }
			
			// INT -> PSZ
			operator implicit( i as int ) as Psz
				return Psz{ IntPtr{ i } }
			
			// DWORD -> PSZ
			operator implicit( d as dword ) as Psz
				return Psz{ IntPtr{ (ptr) d } }
			
			///////////////////////////////////////////////////////////////////////////
			// Conversion Operators - From PSZ...  
			
			// PSZ -> PTR
			operator implicit( p as Psz ) as ptr
				return p:_value
			
			// PSZ -> BYTE PTR
			operator implicit( p as Psz ) as byte ptr
				return p:_value
			
			// PSZ -> SByte PTR
			operator implicit( p as Psz ) as SByte ptr
				return (SByte ptr) p:_value
			
			// PSZ -> IntPtr
			operator implicit( p as Psz ) as IntPtr
				return p:_value
			
			// PSZ -> STRING
			operator implicit( p as Psz ) as string
				return p:ToString()
			
			// PSZ -> INT
			operator implicit( p as Psz ) as int
				return (int) p:_value
			
			// PSZ -> INT64
			operator implicit( p as Psz ) as int64
				return (int64) p:_value
			
			// PSZ -> DWORD
			operator implicit( p as Psz ) as dword
				return (dword) p:_value			
		#endregion
		
		
	end structure
	
end namespace




// This function is handled by the compiler. The runtime function should never be called
function Cast2Psz(cSource as string) as Psz
	THROW NotImplementedException{}

// This function is handled by the compiler. The runtime function should never be called
function String2Psz(cSource as string) as Psz
	throw NotImplementedException{}


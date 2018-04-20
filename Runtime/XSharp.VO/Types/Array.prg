﻿//
// Copyright (c) XSharp B.V.  All Rights Reserved.  
// Licensed under the Apache License, Version 2.0.  
// See License.txt in the project root for license information.
//
using System.Collections
using System.Collections.Generic
using System.Linq
using System.Diagnostics
using System.Reflection
using System.Text
using XSharp
begin namespace XSharp	
	
	[DebuggerDisplay("{DebuggerString(),nq}", Type := "ARRAY")] ;
	[DebuggerTypeProxy(typeof(ArrayDebugView))];
	public sealed class __Array inherit __ArrayBase<usual>
		
		constructor()
			super()
		
		constructor(capacity as dword)
			super(capacity)

		constructor( elements as usual[] )
			self()
			if elements == null
				throw ArgumentNullException{nameof(elements)}
			endif
			_internalList:Capacity := elements:Length
			_internalList:AddRange(elements) 
			return
		
		constructor( elements as object[] )
			self()
			if elements == null
				throw ArgumentNullException{nameof(elements)}
			endif
			foreach element as object in elements
				if element == null
					_internalList:add(default(usual))
				else
					_internalList:Add( usual{ element})
				endif
			next
			return
		
		public static method ArrayCreate(dimensions params int[] ) as Array
			local count := dimensions:Length as int
			if count <= 0
				throw ArgumentException{"No dimensions provided."}
			endif
			local initializer := object[]{dimensions[1]} as object[]
			local arrayNew as Array
			arrayNew := Array{initializer}
			
			if count > 1
				local i as int
				for i:=0+__ARRAYBASE__  upto dimensions[1]-1+__ARRAYBASE__
					local newParams := int[]{count-1} as int[]
					Array.Copy(dimensions,1,newParams,0,count-1)
					arrayNew:_internalList[(int) i-__ARRAYBASE__ ] := __ArrayNew(newParams)
				next
			endif
			return arrayNew
		
		public static method __ArrayNew( dimensions params int[] ) as __Array
			local newArray as Array 
			if dimensions:Length != 0 
				newArray := __ArrayNewHelper(dimensions,1)
			else
				newArray := Array{}
			endif
			return newArray
		
		public static method __ArrayNewHelper(dimensions as int[], currentDim as int) as Array
			local capacity  as dword // one based ?
			local newArray as Array
			capacity := (dword) dimensions[currentDim]
			newArray := Array{capacity} 
			if currentDim != dimensions:Length
				local nextDim := currentDim+1 as int
				local index   := 1 as int
				do while index <= capacity
					newArray:Add(usual{__ArrayNewHelper(dimensions,nextDim)})
					index+=1
				enddo
				return newArray
			endif
			return newArray

		internal new method Clone() as Array
			local aResult as Array
			local nCount as dword
			nCount := (dword) _internalList:Count
			aResult := Array{nCount}
			for var I := 0 to nCount-1
				var u := _internalList[i]
				if u:isArray
					var aElement := (Array) u
					aResult:_internalList[i] := aElement:Clone()
				else
					aResult:_internalList[i] := u
				endif
			next
			return aResult

		internal method CloneShallow() as Array
			return (Array) super:Clone()

		public property self[i as dword, j as dword, k as DWORD] as usual
			get
				return __GetElement((int)i,(int)j, (int) k)
			end get
			set
				self:__SetElement(value,(int)i,(int)j,(int) k)
			end set
		end property

		public property self[i as dword, j as dword] as usual
			get
				return __GetElement((int)i,(int)j)
			end get
			set
				self:__SetElement(value,(int)i,(int)j)
			end set
		end property
	
		new property self[index as dword] as usual
			get
				return __GetElement((int)index)
			end get
			set
				__SetElement(value, (int)index)
			end set
		end property
		
		new public method Swap(position as dword, element as usual) as usual
			return super:Swap(position, element)

		new public method Swap(position as int, element as usual) as usual
			return super:Swap(position, element)

		///
		/// <Summary>Access the array element using ZERO based array index</Summary>
		///
		public method __GetElement(index params int[]) as usual
			local indexLength := index:Length as int
			local currentArray := self as Array
			local i as int
			
			for i:= 1  upto indexLength  -1 // walk all but the last level
				local u := currentArray:_internalList[ index[i] ] as usual
				if u:IsNil 
					return u
				endif
				if u:IsArray
					throw InvalidOperationException{"out of range error."}
				endif
				currentArray := (Array) u
			next
			return currentArray:_internalList[ index[i] ]
		internal method DebuggerString() as string
			local sb as StringBuilder
			local cnt, tot as long
			sb := StringBuilder{}
			sb:Append(self:ToString())
			sb:Append("{")
			tot := _internallist:Count
			cnt := 0
			foreach var element in self:_internallist
				if cnt > 0
					sb:Append(",")
				endif
				sb:Append(element:ToString())
				cnt++
				if cnt > 5 
					if cnt < tot
						sb:Append(",..")
					endif
					exit
				endif
			next		
			sb:Append("}")
			return sb:ToString()
		public method __SetElement(u as usual, index params int[] ) as usual
			// indices are 0 based
			if self:CheckLock()
				local length := index:Length as int
				local currentArray := self as Array
				
				for var i := 1 upto length-1
					local uArray := _internalList[index[i]] as usual
					if !(uArray:IsArray)
						throw InvalidOperationException{"Out of range error."}
					endif
					currentArray := (Array) uArray
				next
				currentArray:_internalList[index[length]] := u
			endif
			return u
		
		internal class ArrayDebugView
			private _value as Array
			public constructor (a as Array)
				_value := a
			//[DebuggerBrowsable(DebuggerBrowsableState.RootHidden)] ;
			public property Elements as List<usual> get _value:_internalList
			
		end class
		
	end	class
	
	
end namespace

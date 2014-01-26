// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.soa;

import std.traits;
import std.typetuple;
import std.array : back;


struct Accessor(T) {
	alias FIELDS = FieldTypeTuple!T;	
	alias DynamicArray(T) = T[];	
	alias Pointer(T) = T*;	
	alias ITEM_ARRAY_PTRS = staticMap!(Pointer, staticMap!(DynamicArray, FIELDS));
	ITEM_ARRAY_PTRS _pData;
	size_t _idx;
		
	this(K...)(size_t idx, ref K k) {
		_idx = idx;
		foreach(i, P; K) {
			_pData[i] = &k[i];
		}
	}
	
	private static string _gen() {
		string s;
		foreach(i, F; FIELDS) {
			enum name = T.tupleof[i].stringof;
			//pragma(msg, name);
			s ~= "@property void " ~ name ~ "() const { return ; } \n\n";			
		}
		return s;
	}
	mixin(_gen());
	pragma(msg, _gen());
	
	void test(){
		import std.stdio;
		foreach(ref x; _pData) {
			(*x)[_idx].writeln();
		}
	}
}


/**
Implements an 'Structure of Arrays' Array.
*/
struct ArraySoA(T) if(FieldTypeTuple!(T).length > 0) {
	alias FIELDS = FieldTypeTuple!T;	
	alias DynamicArray(T) = T[];	
	alias ITEM_ARRAYS = staticMap!(DynamicArray, FIELDS);
	ITEM_ARRAYS _data;
	pragma(msg, FIELDS);
	
	
	void opOpAssign(string op : "~")(T t) {		
		foreach(i, ITEM; FIELDS) {
			this._data[i] ~= t.tupleof[i];
		}
	}
	
	void remove(size_t idx) {
		foreach(i, ITEM; FIELDS) {
			_data[i][idx] = _data[i].back;
			_data[i].length -= 1;
		}
	}
	
	size_t length() const @safe nothrow {
		return _data[0].length;
	}
	
	
	Accessor!(T) opIndex(size_t idx) {
		return Accessor!(T)(idx, _data);
	}
}
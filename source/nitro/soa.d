// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.soa;

import std.typetuple;

private alias _ToDynamicArray(T) = T[];	

/**
A TypeTuple containing all fields (recursive!) of type T as dynamic Array. 
*/
template ToSoA(T) {
	import std.traits : RepresentationTypeTuple;
	import std.typetuple : staticMap;
	alias _FIELDS = RepresentationTypeTuple!T;	
	alias ToSoA = staticMap!(_ToDynamicArray, _FIELDS);
}
unittest {
	struct Test0 { char a; }
	struct Test1 { int a; }
	struct Test2 { int a; float b; }
	struct Test3 { Test0 a; Test1 b; Test2 c; }
	struct Test4 { Test0 a; Test1 b; Test2 c; Test3 d; Test0 aa; }
	struct Test5 { int* a; int[] b; int[12] c; }
	
	static assert( is(ToSoA!Test0 == TypeTuple!()));
	static assert( is(ToSoA!Test1 == TypeTuple!(int[]) ));
	static assert( is(ToSoA!Test2 == TypeTuple!(int[], float[]) ));
	static assert( is(ToSoA!Test3 == TypeTuple!(int[], int[], float[]) ));
	static assert( is(ToSoA!Test4 == TypeTuple!(int[], int[], float[], int[], int[], float[]) ));
	static assert( is(ToSoA!Test5 == TypeTuple!(int*[], int[][], int[12][]) ));

//	pragma(msg, "SOA: ", ToSoA!Test0);
//	pragma(msg, "SOA: ", ToSoA!Test1);
//	pragma(msg, "SOA: ", ToSoA!Test2);
//	pragma(msg, "SOA: ", ToSoA!Test3);
//	pragma(msg, "SOA: ", ToSoA!Test4);
//	pragma(msg, "SOA: ", ToSoA!Test5);	
}





struct Accessor(T) {
	import std.traits : RepresentationTypeTuple, FieldTypeTuple;
	import std.typetuple : staticMap;
	import std.conv;
	private alias _ToPointer(T) = T*;	
	alias SOA_PTRS = staticMap!(_ToPointer, ToSoA!T);
	SOA_PTRS _pData;
	size_t _idx;
		
	this(K...)(size_t idx, ref K k) {
		_idx = idx;
		foreach(i, P; K) {
			_pData[i] = &k[i];
		}
	}

	static string _gen() {
		string ret;
		alias FTT = FieldTypeTuple!T;
		foreach(i, F; FTT) {

			enum IDX = (i > 0) ? TypeTuple!(staticMap!(RepresentationTypeTuple, FTT[0..i])).length : 0;
			pragma(msg, IDX);
			
			static if(FieldTypeTuple!F.length > 1) {
				ret ~= "@property Accessor!(" ~ F.stringof ~ ") " ~ to!string(T.tupleof[i].stringof) ~ "(){ return Accessor!(" ~ F.stringof ~ ")(_idx, _pData[" ~ to!string(IDX) ~ ".." ~ to!string(IDX + RepresentationTypeTuple!F.length) ~ "]); };\n";
			}
			else {
				ret ~= "@property " ~ F.stringof ~ " " ~ to!string(T.tupleof[i].stringof) ~ "(){ return _pData[" ~ to!string(IDX) ~ "][_idx]; }\n";
			}
		}
		return ret;
	}

	pragma(msg, T.stringof);
	pragma(msg, SOA_PTRS.stringof);
	pragma(msg, _gen());
	
	void test(){
		import std.stdio;
		foreach(ref x; _pData) {
			(*x)[_idx].writeln();
		}
	}
}




import std.array : back;

/**
Implements an 'Structure of Arrays' Array.
*/
struct SoAArray(T) {
	ToSoA!T _data;
	
	void opOpAssign(string op : "~")(T t) {		
		foreach(i, Field; ToSoA!T) {
			this._data[i] ~= t.tupleof[i];
		}
	}
	
	void remove(size_t idx) {
//		foreach(i, Field; ToSoA!T) {
//			_data[i][idx] = _data[i].back;
//			_data[i].length -= 1;
//		}
	}
	
	size_t length() const @safe nothrow {
		return _data[0].length;
	}
	
	
	Accessor!(T) opIndex(size_t idx) {
		return Accessor!(T)(idx, _data);
	}
}
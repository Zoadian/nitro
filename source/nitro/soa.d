// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.soa;

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
	struct Test0 { }
	struct Test1 { int a; }
	struct Test2 { int a; float b; }
	struct Test3 { Test0 a; Test1 b; Test2 c; }
	struct Test4 { Test0 a; Test1 b; Test2 c; Test3 d; }
	struct Test5 { int* a; int[] b; int[12] c; }
	
	static assert( is(ToSoA!Test0 == TypeTuple!()));
	static assert( is(ToSoA!Test1 == TypeTuple!(int[]) ));
	static assert( is(ToSoA!Test2 == TypeTuple!(int[], float[]) ));
	static assert( is(ToSoA!Test3 == TypeTuple!(int[], int[], float[]) ));
	static assert( is(ToSoA!Test4 == TypeTuple!(int[], int[], float[], int[], int[], float[]) ));
	static assert( is(ToSoA!Test5 == TypeTuple!(int*[], int[][], int[12][]) ));

	//~ pragma(msg, "SOA: ", ToSoA!Test0);
	//~ pragma(msg, "SOA: ", ToSoA!Test1);
	//~ pragma(msg, "SOA: ", ToSoA!Test2);
	//~ pragma(msg, "SOA: ", ToSoA!Test3);
	//~ pragma(msg, "SOA: ", ToSoA!Test4);
	//~ pragma(msg, "SOA: ", ToSoA!Test5);	
}














string _GEN(size_t ) {
	
}




struct Accessor(T) {
	import std.traits : RepresentationTypeTuple;
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
	
	
	
	template _GEN(T...) {
		alias FTT = FieldTypeTuple!T;
		alias RTT = RepresentationTypeTuple!T;
		
		alias _GEN = _GEN();
	}
	
	
	
	private static string _gen() {
		string s;
		size_t idxData = 0;
		foreach(i, K; typeof(T.tupleof)) {
				pragma(msg, "PENS", SOA_PTRS[idxData]);
			static if(is(SOA_PTRS[idxData] == _ToDynamicArray!K*)) {
				pragma(msg, "YES: ", K.stringof);
				s ~= "@property " ~ K.stringof ~ " " ~ T.tupleof[i].stringof ~ "() const { return _pData[" ~ to!string(idxData) ~ "][_idx]; } \n\n";
				++idxData;
			}
			else {
				pragma(msg, "NOO: ", K.stringof);
				//idxData += RepresentationTypeTuple!K.length;
				//s ~= "@property Accessor!" ~ K.stringof ~ " " ~ T.tupleof[i].stringof ~ "() const { return ; } \n\n";
			}
		}
		
		
		//~ foreach(i, F; SOA_PTRS) {
			//~ static if(is(F == _ToDynamicArray!(typeof(T.tupleof[i]))*)) {
				//~ enum name = T.tupleof[i].stringof;
				//~ s ~= "@property void " ~ name ~ "() const { return ; } \n\n";
			//~ }
			//~ else {
				//~ import std.traits : RepresentationTypeTuple;
				//~ //pragma(msg, RepresentationTypeTuple!(typeof(T.tupleof[i])));
				//~ //pragma(msg, F, "\t", T.tupleof.stringof, "\t", i, "\t", typeof(T.tupleof[i]), "\t", is(F == _ToDynamicArray!(typeof(T.tupleof[i]))*));
			//~ }						
		//~ }
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
		foreach(i, Field; ToSoA!T) {
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
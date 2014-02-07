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
    import std.stdio : writeln; 
    writeln("################## SOA UNITTEST START ##################");

	struct Test0 { }
	struct Test1 { int a; }
	struct Test2 { int a; float b; }
	struct Test3 { Test0 a; Test1 b; Test2 c; }
	struct Test4 { Test0 a; Test1 b; Test2 c; Test3 d; Test0 aa; }
	struct Test5 { int* a; int[] b; int[12] c; }
	
	//~ static assert( is(ToSoA!Test0 == TypeTuple!(char[])));
	//~ static assert( is(ToSoA!Test1 == TypeTuple!(int[]) ));
	//~ static assert( is(ToSoA!Test2 == TypeTuple!(int[], float[]) ));
	//~ static assert( is(ToSoA!Test3 == TypeTuple!(int[], int[], float[]) ));
	//~ static assert( is(ToSoA!Test4 == TypeTuple!(int[], int[], float[], int[], int[], float[]) ));
	//~ static assert( is(ToSoA!Test5 == TypeTuple!(int*[], int[][], int[12][]) ));

    writeln("################## SOA UNITTEST STOP  ##################");
}





struct Accessor(T) {
	import std.traits : RepresentationTypeTuple, FieldTypeTuple, fullyQualifiedName, moduleName, isPointer;
	import std.typetuple : staticMap;
	import std.conv;
	private alias _ToPointer(T) = T*;	
	alias SOA_PTRS = staticMap!(_ToPointer, ToSoA!T);
	SOA_PTRS _pData;
	size_t _idx;
		
	this(K...)(size_t idx, ref K k) {
		_idx = idx;
		foreach(i, P; K) {
			static if(isPointer!(P)) {
				_pData[i] = k[i];
			}
			else {
				_pData[i] = &k[i];
			}
		}
	}

	static string _gen() {
		string ret;
		alias FTT = FieldTypeTuple!T;
		foreach(i, F; FTT) {
			enum IDX = (i > 0) ? TypeTuple!(staticMap!(RepresentationTypeTuple, FTT[0..i])).length : 0;
				
			//~ pragma(msg, fullyQualifiedName!F);
						
			static if(FieldTypeTuple!F.length > 1) {
				ret ~= "import " ~ moduleName!F ~"; \n";
				ret ~= "@property Accessor!(" ~ fullyQualifiedName!F ~ ") " ~ to!string(T.tupleof[i].stringof) ~ "(){ return Accessor!(" ~ fullyQualifiedName!F ~ ")(_idx, _pData[" ~ to!string(IDX) ~ ".." ~ to!string(IDX + RepresentationTypeTuple!F.length) ~ "]); };\n";
			}
			else {
				ret ~= "@property ref " ~ F.stringof ~ " " ~ to!string(T.tupleof[i].stringof) ~ "(){ return (*_pData[" ~ to!string(IDX) ~ "])[_idx]; }\n";
			}
		}
		return ret;
	}
	
	pragma(msg, _gen());
	mixin(_gen());
	/*
	void test(){
		import std.stdio;
		foreach(ref x; _pData) {
			if((*x).length > _idx) 
			(*x)[_idx].writeln();
		}
	}
	*/
}




import std.array : back;
import std.traits : RepresentationTypeTuple, FieldTypeTuple;



/**
Implements an 'Structure of Arrays' Array.
*/
struct SoAArray(T) if(FieldTypeTuple!T.length > 0) {
	ToSoA!T _data;
	
	void opOpAssign(string op : "~")(T t) {	
		void fnAssign(size_t idx, X)(X x){		
			foreach(i, F; FieldTypeTuple!X) {
				enum IDX = (i > 0) ? idx + TypeTuple!(staticMap!(RepresentationTypeTuple, FieldTypeTuple!X[0..i])).length : idx;
				static if(FieldTypeTuple!F.length > 1) {
					fnAssign!(IDX)(x.tupleof[i]);
				}
				else {
					this._data[IDX] ~= x.tupleof[i];
				}
			}
		}
		fnAssign!(0)(t);
	}

	void insertInPlace(size_t pos, T t) {	
		import std.array : insertInPlace;
		void fnAssign(size_t idx, X)(X x){		
			import std.array : insertInPlace;
			foreach(i, F; FieldTypeTuple!X) {
				enum IDX = (i > 0) ? idx + TypeTuple!(staticMap!(RepresentationTypeTuple, FieldTypeTuple!X[0..i])).length : idx;
				static if(FieldTypeTuple!F.length > 1) {
					fnAssign!(IDX)(x.tupleof[i]);
				}
				else {
					this._data[IDX].insertInPlace(pos, x.tupleof[i]);
				}
			}
		}
		fnAssign!(0)(t);
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
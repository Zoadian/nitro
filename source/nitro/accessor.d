//###################################################################################################
/**
* Copyright: Copyright Felix 'Zoadian' Hufnagel 2014- and Paul Freund 2014-.
* License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
* Authors: $(WEB zoadian.de, Felix 'Zoadian' Hufnagel) and $(WEB lvl3.org, Paul Freund).
*/
//###################################################################################################

module nitro.accessor;

//###################################################################################################

enum SoA;
enum AoS;

template isAoS(T) {
	import std.typetuple : staticMap, anySatisfy;
	enum isAoSAttribute(T) = is(T == AoS);
	static if(__traits(compiles, __traits(getAttributes, T)))
		enum isAoS = (anySatisfy!(isAoSAttribute, __traits(getAttributes, T)));
	else
		enum isAoS = false;
}

//---------------------------------------------------------------------------------------------------

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

    writeln("################## SOA UNITTEST STOP  ##################");
}





struct Accessor(T) {

	// Use AoS
	static if(isAoS!(T)) {
		T* _data;

		this(ref T t) @trusted nothrow {
			_data = &t;
		}

		alias FTT = FieldTypeTuple!T;
		static string _gen() @safe {
			string ret;
			foreach(i, F; FTT) {
				enum fn_ret_str = F.stringof;
				enum fn_name_str = T.tupleof[i].stringof;
				ret ~= "@property ref " ~ fn_ret_str ~ " " ~ fn_name_str ~ "(){ return _data." ~ fn_name_str ~ "; }\n";
			}
			return ret;
		}

		//pragma(msg, "GEN: ", _gen());
		mixin(_gen());
	}

	// Use SoA
	else {
		import std.traits : RepresentationTypeTuple, FieldTypeTuple, fullyQualifiedName, moduleName, isPointer;
		import std.typetuple : staticMap;
		import std.conv;
		private alias _ToPointer(T) = T*;	
		alias SOA_PTRS = staticMap!(_ToPointer, ToSoA!T);
		SOA_PTRS _pData;
		size_t _idx;
		
		this(K...)(size_t idx, ref K k) @trusted nothrow {
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

		alias FTT = FieldTypeTuple!T;

		template AccessorOf(T) {
			static if(FieldTypeTuple!(T).length > 1) {
				alias AccessorOf = Accessor!T;
			}
			else {
				alias AccessorOf = T;
			}
		}

		alias _ACCESSORS = staticMap!(AccessorOf, FTT);

		static string _gen() @safe {
			import std.typetuple : TypeTuple;
			string ret;
			foreach(i, F; FTT) {
				enum IDX = (i > 0) ? TypeTuple!(staticMap!(RepresentationTypeTuple, FTT[0..i])).length : 0;
				enum idx_str = to!string(IDX);

				enum fn_ret_str = " _ACCESSORS[" ~ to!string(i) ~ "] ";
				enum fn_name_str = T.tupleof[i].stringof;

				static if(FieldTypeTuple!F.length > 1) {
					ret ~= "@property" ~ fn_ret_str ~ fn_name_str ~ "(){ return " ~ fn_ret_str ~ "(_idx, _pData[" ~ to!string(IDX) ~ ".." ~ to!string(IDX + RepresentationTypeTuple!F.length) ~ "]); };\n";
				}
				else {
					ret ~= "@property ref" ~ fn_ret_str ~ fn_name_str ~ "(){ return (*_pData[" ~ to!string(IDX) ~ "])[_idx]; }\n";
				}
			}
			return ret;
		}
	
		mixin(_gen());
	}
}




import std.array : back;
import std.traits : RepresentationTypeTuple, FieldTypeTuple;



/**
Implements an 'Structure of Arrays' Array.
*/
struct SoAArray(T) if(FieldTypeTuple!T.length > 0) {

	// Use AoS
	static if(isAoS!(T)) {
		_ToDynamicArray!(T) _data;

		void opOpAssign(string op : "~")(T t) @safe nothrow {
			_data ~= t;
		}

		public import std.algorithm : SwapStrategy;
		void remove(SwapStrategy swapStrategy = SwapStrategy.stable)(size_t idx) {
			import std.algorithm : remove;
			_data = remove!swapStrategy(_data, idx);
		}

		void insertInPlace(size_t pos, T t) nothrow {
			import std.array : insertInPlace;
			_data.insertInPlace(pos, t);
		}

		size_t length() const @safe nothrow {
			return _data.length;
		}

		Accessor!(T) opIndex(size_t idx) @safe nothrow {
			return Accessor!(T)(_data[idx]);
		}
	}
	// Use SoA
	else {
		ToSoA!T _data;
	
		void opOpAssign(string op : "~")(T t) @safe nothrow {

			void fnAssign(size_t idx, X)(X x) @safe nothrow {	
				import std.typetuple : TypeTuple, staticMap;
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

		void insertInPlace(size_t pos, T t) @safe nothrow {

			void fnAssign(size_t idx, X)(X x) @trusted nothrow {	
				import std.typetuple : TypeTuple, staticMap;
				import std.array : insertInPlace;
				foreach(i, F; FieldTypeTuple!X) {
					enum IDX = (i > 0) ? idx + TypeTuple!(staticMap!(RepresentationTypeTuple, FieldTypeTuple!X[0..i])).length : idx;
					static if(FieldTypeTuple!F.length > 1) {
						fnAssign!(IDX)(x.tupleof[i]);
					}
					else {
						import std.array : insertInPlace;
						this._data[IDX].insertInPlace(pos, x.tupleof[i]);
					}
				}
			}

			fnAssign!(0)(t);
		}

		public import std.algorithm : SwapStrategy;
		void remove(SwapStrategy swapStrategy = SwapStrategy.stable)(size_t idx) @safe {
			foreach(i, Field; ToSoA!T) {
				import std.algorithm : remove;
				_data[i] = remove!swapStrategy(_data[i], idx);
			}
		}
	
		size_t length() const @safe nothrow {
			return _data[0].length;
		}
	
	
		Accessor!(T) opIndex(size_t idx) @safe nothrow {
			return Accessor!(T)(idx, _data);
		}

	}

}

//###################################################################################################

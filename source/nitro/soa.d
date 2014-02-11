// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/

module nitro.soa;

//---------------------------------------------------------------------------------------------------

import std.typetuple;

//---------------------------------------------------------------------------------------------------

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

version(unittest) {
    static bool bCheckSystemOneConstructor = false;
    static bool bCheckSystemTwoConstructor = false;

    static int runCountSystemOne = 0;
    static int runCountSystemTwo = 0;

    final class SystemOne(ECM) {
        string _identifier;

        this() {
            _identifier = "SystemOne";
            bCheckSystemOneConstructor = true;
        }

        void run(ECM ecm) {
            runCountSystemOne++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!AoS_ComponentThree()) {
                assert(runCountSystemOne == 2);
                countComponentThreeFound++;

                ecm.deleteLater!AoS_ComponentThree(e);
                ecm.deleteLater(e);

                ecm.addComponents(ecm.createEntity(), AoS_ComponentOne(10,"a",true), AoS_ComponentThree());
                ecm.addComponents(ecm.createEntity(), AoS_ComponentTwo(11,"b",false), AoS_ComponentThree());
            }

            if(runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 1); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }

			ecm.executeDelete();
        }
    }

    final class SystemTwo(ECM) {
        ECM _ecm;
        string _identifier;

        this(ECM ecm) {
            _identifier = "SystemTwo";
            _ecm = ecm;
            bCheckSystemTwoConstructor = true;
        }

        void run(ECM ecm) {
            runCountSystemTwo++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!AoS_ComponentThree()) {
                assert(runCountSystemOne == 2);
                countComponentThreeFound++;

				//                Entity en = e;
				//                if(e.hasComponent!ComponentOne()) {
				//                    assert(!e.hasComponent!ComponentTwo());
				//                    auto component = e.getComponent!ComponentOne();
				//                    if(runCountSystemOne == 2) { assert(en.id == 5 && component.FieldOne == 10 && component.FieldTwo == "a" && component.FieldThree == true); }
				//                }
				//                if(e.hasComponent!ComponentTwo()) {
				//                    assert(!e.hasComponent!ComponentOne());
				//                    auto component = e.getComponent!ComponentTwo();
				//                    if(runCountSystemOne == 2) { assert(en.id == 6 && component.FieldOne == 11 && component.FieldTwo == "b" && component.FieldThree == false); }
				//                }
                ecm.clearLater(e);
            }

            if(runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 2); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }


			ecm.executeDelete();
        }
    }

    @AoS struct  AoS_ComponentOne {
        int FieldOne;
        string FieldTwo;
        bool FieldThree;
    }

    @AoS struct AoS_ComponentTwo { 
        int FieldOne;
        string FieldTwo;
        bool FieldThree;
    }

	@AoS struct AoS_ComponentThree {
		int a;
	}

	@AoS struct AoS_ComponentFour {
	}
}

unittest {
	import nitro.ecs;
	import std.typetuple : TypeTuple;
    import std.stdio : writeln; 
    writeln("################## AOS UNITTEST START ##################");

	alias TEST_SYSTEMS = TypeTuple!(SystemOne, SystemTwo);
	alias TEST_COMPONENTS = TypeTuple!(AoS_ComponentOne, AoS_ComponentTwo, AoS_ComponentThree, AoS_ComponentFour);

	alias TEST_ECM = EntityComponentManager!(TEST_COMPONENTS);
	alias TEST_ECS = SystemManager!(TEST_ECM, TEST_SYSTEMS);

	// Test system functions
	TEST_ECS test_ecs = new TEST_ECS();

    assert(bCheckSystemOneConstructor);
    assert(bCheckSystemTwoConstructor);

	auto system_one = test_ecs.system!SystemOne();
	auto system_two = test_ecs.system!SystemTwo();

    assert(system_one._identifier == "SystemOne");
    assert(system_two._identifier == "SystemTwo");

    assert(runCountSystemOne == 0);
    assert(runCountSystemTwo == 0);

	test_ecs.run();

    assert(runCountSystemOne == 1);
    assert(runCountSystemTwo == 1);

	// Test entity/component functions
	auto test_ecm = test_ecs.ecm;

	Entity entity_one = test_ecm.createEntity();
	Entity entity_two = test_ecm.createEntity();
	Entity entity_three = test_ecm.createEntity();


	test_ecm.deleteLater(entity_three);
	test_ecm.executeDelete();

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.addComponents(entity_one, AoS_ComponentOne(1, "hi", true));

	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one)); 
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two)); 
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two)); 

	assert(!test_ecm.hasComponents!(AoS_ComponentOne,AoS_ComponentTwo)(entity_one));

	test_ecm.deleteLater!AoS_ComponentOne(entity_one);
	test_ecm.executeDelete();

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.addComponents(entity_two, AoS_ComponentOne(2, "ho", false));
	test_ecm.addComponents(entity_two, AoS_ComponentTwo(3, "lets", true));

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.addComponents(entity_one, AoS_ComponentOne(4, "go", false));
	test_ecm.addComponents(entity_one, AoS_ComponentTwo(5, "this", true));

	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	assert(test_ecm.hasComponents!(AoS_ComponentOne,AoS_ComponentTwo)(entity_one));
	assert(test_ecm.hasComponents!(AoS_ComponentOne,AoS_ComponentTwo)(entity_two));

	auto component_one = test_ecm.getComponent!AoS_ComponentOne(entity_one);
    assert(component_one.FieldOne == 4 && component_one.FieldTwo == "go" && component_one.FieldThree == false);

	Entity entity_four = test_ecm.createEntity();
	test_ecm.addComponents(entity_four, AoS_ComponentOne(6, "is", false));
	test_ecm.addComponents(entity_four, AoS_ComponentTwo(6, "my", true));
    test_ecm.deleteLater(entity_four);

	Entity lastEntity = Entity(size_t.max);
    int currentIteration = 1;
	foreach(e; test_ecm.query!(AoS_ComponentOne, AoS_ComponentTwo)()) {
        assert(currentIteration <= 3);

		auto component = e.getComponent!AoS_ComponentOne();
		Entity en = cast(Entity)e;
        if(currentIteration == 1) { assert(en.id == 0 && component.FieldOne == 4 && component.FieldTwo == "go" && component.FieldThree == false); }
        if(currentIteration == 2) { assert(en.id == 1 && component.FieldOne == 2 && component.FieldTwo == "ho" && component.FieldThree == false); }
        if(currentIteration == 3) { assert(en.id == 3 && component.FieldOne == 6 && component.FieldTwo == "is" && component.FieldThree == false); }

		auto componenttwo = e.getComponent!AoS_ComponentTwo();
		Entity entwo = cast(Entity)e;
        if(currentIteration == 1) { assert(entwo.id == 0 && componenttwo.FieldOne == 5 && componenttwo.FieldTwo == "this" && componenttwo.FieldThree == true); }
        if(currentIteration == 2) { assert(entwo.id == 1 && componenttwo.FieldOne == 3 && componenttwo.FieldTwo == "lets" && componenttwo.FieldThree == true); }
        if(currentIteration == 3) { assert(entwo.id == 3 && componenttwo.FieldOne == 6 && componenttwo.FieldTwo == "my" && componenttwo.FieldThree == true); }

        assert(en == entwo);
		if(lastEntity != Entity(size_t.max)) {
            assert(!(lastEntity.id > en.id));
		}
		lastEntity = en;
        currentIteration++;
	}

	test_ecm.deleteLater!AoS_ComponentTwo(entity_one);
	test_ecm.deleteLater!AoS_ComponentOne(entity_two);
	test_ecm.executeDelete();

    int currentIterationTwo = 1;
	foreach(e; test_ecm.query!AoS_ComponentOne()) {
        assert(currentIterationTwo <= 2);

		auto component = e.getComponent!AoS_ComponentOne();
		Entity en = e;
        if(currentIterationTwo == 1) { assert(en.id == 0 && component.FieldOne == 4 && component.FieldTwo == "go" && component.FieldThree == false); }
        if(currentIterationTwo == 2) { assert(en.id == 1 && component.FieldOne == 3 && component.FieldTwo == "lets" && component.FieldThree == true); }
        currentIterationTwo++;
	}

    int currentIterationThree = 1;
	foreach(e; test_ecm.query!AoS_ComponentTwo()) {
        assert(currentIterationThree <= 1);
		auto component = e.getComponent!AoS_ComponentTwo();
		Entity en = e;
        if(currentIterationThree == 1) { assert(en.id == 1 && component.FieldOne == 3 && component.FieldTwo == "lets" && component.FieldThree == true); }
        currentIterationThree++;
	}

	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_one)) ;
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_two)) ;

	test_ecm.deleteLater!AoS_ComponentOne(entity_one);
	test_ecm.deleteLater!AoS_ComponentTwo(entity_two);
	test_ecm.executeDelete();

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.deleteLater(entity_one);
	test_ecm.deleteLater(entity_two);
	test_ecm.executeDelete();

	Entity entity_emitter = test_ecm.createEntity();
	test_ecm.addComponents(entity_emitter, AoS_ComponentThree());

	test_ecs.run();
    assert(runCountSystemOne == 2);
    assert(runCountSystemTwo == 2);

	test_ecs.run();
    assert(runCountSystemOne == 3);
    assert(runCountSystemTwo == 3);

    writeln("################## AOS UNITTEST STOP  ##################");
}
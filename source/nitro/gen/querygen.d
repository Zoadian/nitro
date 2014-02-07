// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel), $(WEB lvl3.org, Paul Freund)
*/
module nitro.gen.querygen;

import nitro.soa;
//---------------------------------------------------------------------------------------------------

auto pushEntity(ECM, ARGS...)(ECM ecm, ARGS args) {
	auto e = ecm.createEntity();
	foreach(arg;args) {
        ecm.addComponents(e, arg);
	}
    return e;
}

//---------------------------------------------------------------------------------------------------
mixin template AutoQuery() {
	void run(ECM)(ECM ecm) {
		mixin AutoQueryMapper!(ecm);
	}
}

//---------------------------------------------------------------------------------------------------
alias QRY = Accessor;
mixin template AutoQueryMapper(alias ECM) {
	
    private template IterateQueryFkts(PARENT, LIST...) if(LIST.length > 0) {
        import std.traits : ParameterTypeTuple, ReturnType;
		import std.typetuple : staticMap; 

		alias ELEMENT = LIST[0];
		alias RETURN_TYPE = ReturnType!(ELEMENT);

		static if(is(RETURN_TYPE == void) || is(RETURN_TYPE == bool)) {
			alias ELEMENT_PARAMS = ParameterTypeTuple!(ELEMENT);

			enum ToString(T) = T.stringof;

			private template GetBareType(string TYPE_STRING) {
				import std.algorithm : startsWith, endsWith;
				enum QUERY_IDENTIFIER = "QRY!";
				pragma(msg, "QUERY_IDENTIFIER: ", QUERY_IDENTIFIER);
				static if(TYPE_STRING.startsWith(QUERY_IDENTIFIER)) {
					enum BARE_TYPE = TYPE_STRING[QUERY_IDENTIFIER.length..$];
					pragma(msg, "BARE_TYPE: ", BARE_TYPE);
					static if(BARE_TYPE.startsWith("(") && BARE_TYPE.endsWith(")"))
						enum GetBareType = BARE_TYPE[1..($-1)];
					else
						enum GetBareType = BARE_TYPE;
				}
			}

			enum RESULT = generateAutoQueries!(ECM, is(RETURN_TYPE==bool), staticMap!(GetBareType, staticMap!(ToString, ELEMENT_PARAMS)));
			pragma(msg, RESULT);
		}

        static if(!__traits(compiles, RESULT)) { enum RESULT = ""; }
		static if(LIST.length > 1)
			enum IterateQueryFkts = RESULT ~ " " ~ IterateQueryFkts!(PARENT, LIST[1..$]);
		else
			enum IterateQueryFkts = RESULT;
    }

    static if(__traits(compiles, __traits(getOverloads, typeof(this), "query"))) {
		private import std.algorithm : sort;
		private import std.array : array;
		bool AutoQueryFkt() { 
			bool deleteEntity = false;
			mixin(IterateQueryFkts!(typeof(this), __traits(getOverloads, typeof(this), "query")));
			ECM.deleteNow();
			return true; 
		}
	    bool autoQueryFktExecuted = AutoQueryFkt();
    }
}


//---------------------------------------------------------------------------------------------------
string generateAutoQueries(alias ECM, bool isBool, PARAMS...)() {
    string code = "";
	string ecmIdentifier = __traits(identifier, ECM); 

	// Remove optional ecs parameter from list
	static if(PARAMS[0] == typeof(ECM).stringof) {
        enum ecmDefined = true;
		alias TYPES_WITHOUT_ECM = PARAMS[1..$];
    }
    else {
        enum ecmDefined = false;
		alias TYPES_WITHOUT_ECM = PARAMS;
    }

    // Remove optional entity parameter from list
    static if(TYPES_WITHOUT_ECM[0] == "Entity") {
        enum entityDefined = true;
		alias TYPES = TYPES_WITHOUT_ECM[1..$];
    }
    else {
        enum entityDefined = false;
		alias TYPES = TYPES_WITHOUT_ECM;
    }

	// Generate list of types
	string typeList = "";
	foreach(TYPE; TYPES) {
		if(typeList.length != 0) { typeList ~= ","; }
		typeList ~= TYPE;
	}
//~ version(none){
	// Start loop over all entities
	code ~= "foreach(e;" ~ ecmIdentifier ~ ".query!(" ~ typeList ~ ")()){";

	// Get return value if bool return
	if(isBool) { code ~= "deleteEntity="; }

	// invoke query function
	code ~= "query(";

	// Supply optional ecm parameter if defined
	static if(ecmDefined) { code ~= ecmIdentifier ~ ","; }

	// Supply optional entity parameter if defined
	static if(entityDefined) { code ~= "e,"; }

	// Supply all component parameters
	foreach(i, TYPE; TYPES) {
        code ~= "e.getComponent!(" ~ TYPE ~ ")()";
		code ~= (i < (TYPES.length-1)) ? "," : ");";
	}

	// If function returns bool, remove component if true
	if(isBool) { code ~= "if(deleteEntity){" ~ ecmIdentifier ~ ".deleteLater(e); }"; }

	// Close entity iteration
	code ~= "}";
//~ }
    return code;
}

//###################################################################################################

version(none) {
	mixin template FANCY() {
		import std.typetuple;
		import std.typecons;
		import std.traits;
		import std.algorithm;
		alias FNS = typeof(__traits(getOverloads, typeof(this), "query"));	

		void fancyfy(ECM)(ECM ecm) {
			foreach(i, FN; FNS) {
				alias COMPONENT_LIST = ParameterTypeTuple!FN;

				foreach(e; ecm.query!(COMPONENT_LIST)) {

					auto getComponent(COMPONENT)() {
						return ecm.getComponent!COMPONENT(e);
					}

					enum isNotTypeofEcs(T) = is(T == ECM);

					alias CALL_LIST = Filter!(isNotTypeofEcs, staticMap!(getComponent, COMPONENT_LIST));
					pragma(msg, typeof(CALL_LIST));

					// Todo: supply ecm as first parameter if defined

					static if(is(ReturnType!FN == bool)) {
						bool doDelete = __traits(getOverloads, typeof(this), "query")[i](*CALL_LIST[0]());
						// Todo: delete entity if true
					}
					else static if(is(ReturnType!FN == void)) {
						// Todo: call all in list
						__traits(getOverloads, typeof(this), "query")[i](*CALL_LIST[0]());
					}
					else {
						static assert(0, "Something is bad");
					}
				}
			}	
		}
	}
}

//###################################################################################################

version(unittest) {
    import nitro;
    @Component struct ComponentOne { string message; }
    @Component struct ComponentTwo { string message; }
    @Component struct ComponentThree { string message; }
    @Component struct ComponentFour { string message; }

    @Component struct ComponentFive { string message; }
    @Component struct ComponentSix { string message; }

    @System final class SystemOne(ECM) {

        void run(ECM ecm) {
            mixin AutoQueryMapper!ecm;
        }

        void query(Accessor!ComponentOne c) {
            assert(c.message == "CheckSum: ");
            c.message ~= "VC;";
        }

        void query(ECM m, Accessor!ComponentOne c) {
            assert(c.message == "CheckSum: VC;");
            c.message ~= "VMC;";
        }

        void query(Entity e, Accessor!ComponentOne c) {
            assert(e == Entity(0));
            assert(c.message == "CheckSum: VC;VMC;");
            c.message ~= "VEC;";
        }

        void query(ECM m, Entity e, Accessor!ComponentOne c) {
            assert(e == Entity(0));
            assert(c.message == "CheckSum: VC;VMC;VEC;");
            c.message ~= "VMEC;";
        }

        void query(Accessor!ComponentThree c, Accessor!ComponentFour c2) {
            assert(c.message == "Check: ");
            assert(c2.message == "Sum: ");
            c.message ~= "VCC;";
            c2.message ~= "VCC;";
        }

        void query(ECM m, Accessor!ComponentThree c, Accessor!ComponentFour c2) {
            assert(c.message == "Check: VCC;");
            assert(c2.message == "Sum: VCC;");
            c.message ~= "VMCC;";
            c2.message ~= "VMCC;";
        }

        void query(Entity e, Accessor!ComponentThree c, Accessor!ComponentFour c2) {
            assert(e == Entity(2));
            assert(c.message == "Check: VCC;VMCC;");
            assert(c2.message == "Sum: VCC;VMCC;");
            c.message ~= "VECC;";
            c2.message ~= "VECC;";
        }

        void query(ECM m, Entity e, Accessor!ComponentThree c, Accessor!ComponentFour c2) {
            assert(e == Entity(2));
            assert(c.message == "Check: VCC;VMCC;VECC;");
            assert(c2.message == "Sum: VCC;VMCC;VECC;");
            c.message ~= "VMECC;";
            c2.message ~= "VMECC;";
        }
    }

    @System final class SystemTwo(ECM) {

        mixin AutoQuery;

        bool query(Accessor!ComponentOne c) {
            assert(c.message == "CheckSum: VC;VMC;VEC;VMEC;");
            c.message ~= "2VC;";
            return false;
        }

        bool query(Accessor!ComponentThree c, Accessor!ComponentFour c2) {
            assert(c.message == "Check: VCC;VMCC;VECC;VMECC;");
            assert(c2.message == "Sum: VCC;VMCC;VECC;VMECC;");
            c.message ~= "2VCC;";
            c2.message ~= "2VCC;";
            return false;
        }

        bool query(Accessor!ComponentTwo c) {
            assert(c.message == "DeleteThis");
            return true;
        }

        bool query(Accessor!ComponentFive c, ComponentSix c2) {
            assert(c.message == "Delete");
            assert(c2.message == "This");
            return true;
        }
    }
}

unittest {
    import std.stdio : writeln; 
    writeln("################## GEN.QUERYGEN UNITTEST START ##################");

	// Test gen ecs functionality
	mixin MakeECS!("autoECS", "nitro.gen.querygen");

    Entity e = autoECS.ecm.pushEntity(ComponentOne("CheckSum: "));

    autoECS.run();

    auto component = autoECS.ecm.getComponent!ComponentOne(e);
    assert(component.message == "CheckSum: VC;VMC;VEC;VMEC;2VC;");

    autoECS.ecm.deleteLater(e);
    autoECS.ecm.deleteNow();

    Entity e2 = autoECS.ecm.pushEntity(ComponentTwo("DeleteThis"));

    autoECS.run();

    assert(!autoECS.ecm.isValid(e));
    assert(!autoECS.ecm.isValid(e2));

    Entity e3 = autoECS.ecm.pushEntity(ComponentThree("Check: "), ComponentFour("Sum: "));

    autoECS.run();

    auto componentThree = autoECS.ecm.getComponent!ComponentThree(e3);
    auto componentFour = autoECS.ecm.getComponent!ComponentFour(e3);
    assert(componentThree.message == "Check: VCC;VMCC;VECC;VMECC;2VCC;");
    assert(componentFour.message == "Sum: VCC;VMCC;VECC;VMECC;2VCC;");

    autoECS.ecm.deleteLater(e3);
    autoECS.ecm.deleteNow();

    Entity e4 = autoECS.ecm.pushEntity(ComponentFive("Delete"), ComponentSix("This"));

    autoECS.run();

    assert(!autoECS.ecm.isValid(e));
    assert(!autoECS.ecm.isValid(e2));
    assert(!autoECS.ecm.isValid(e3));
    assert(!autoECS.ecm.isValid(e4));

    writeln("################## GEN.QUERYGEN UNITTEST STOP  ##################");
}
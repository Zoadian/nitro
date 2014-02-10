// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel), $(WEB lvl3.org, Paul Freund)
*/

/*

	Todo:
	* Cleanup code
	* Make overloaded query functions work
	* Test mixed arguments
	* Update unittests to work and include mixed arguments/overloads/free function names

*/

module nitro.gen.querygen;

import nitro.soa;
//---------------------------------------------------------------------------------------------------

alias Qry = Accessor;

//---------------------------------------------------------------------------------------------------

template TemplateInfo( T ) {
	static if ( is( T t == U!V, alias U, V... ) ) {
		alias U Template;
		alias V Arguments;
	}
}

template MemberFunctions(T) {
	import std.typetuple : staticMap; 
	template ToFunctionType(string functionName) {
		import std.traits : MemberFunctionsTuple;
		alias ToFunctionType = MemberFunctionsTuple!(T, functionName);
	}
	alias MemberFunctions = staticMap!(ToFunctionType, __traits(allMembers, T));
}

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
mixin template AutoQueryMapper(alias ECM) {

	//import std.typetuple : TypeTuple, EraseAll, staticMap, allSatisfy, anySatisfy; 
	//import std.traits : ParameterTypeTuple, ReturnType;
	import std.typetuple;
	import std.typecons;
	import std.traits;

	template QueryType(param) {
		static if(is(param == typeof(ECM)) || is(param == Entity)) {
			alias QueryType = void;
		}
		else {
			alias paramInfo = TemplateInfo!param;
			static if(	__traits(compiles, paramInfo.Arguments)			&& 
						paramInfo.Arguments.length == 1					&& 
						is(paramInfo.Arguments[0] == struct)			&& 
						is(param == Accessor!(paramInfo.Arguments[0]))	) {
				alias QueryType = paramInfo.Arguments[0];
			}
			else {
				alias QueryType = bool;
			}
		}
	}

	template QueryTypes(alias T) {
		alias params = ParameterTypeTuple!T;
		alias paramQueryTypes = EraseAll!(void, staticMap!(QueryType, params));
		enum isBool(T) = is(T == bool);
		static if(paramQueryTypes.length > 0 && !anySatisfy!(isBool, paramQueryTypes))
			alias QueryTypes = paramQueryTypes;
		else
			alias QueryTypes = void;
	}

	template SystemQueries(alias SYSTEM) {

		template getQuery(alias functionType) {
			alias returnType = ReturnType!functionType;
			alias queryTypes = QueryTypes!functionType;

			static if(!is(returnType == void) && !is(returnType == bool))
				alias getQuery = void;
			else static if(is(queryTypes == void))
				alias getQuery = void;
			else
				alias getQuery = functionType;
		}

		alias SystemQueries = EraseAll!(void, staticMap!(getQuery, MemberFunctions!SYSTEM));		  

	}	

	mixin template InvokeQueries(QUERIES...) {
		static if(QUERIES.length > 0) {
			bool AutoQueryFkt() { 
				foreach(QUERY;QUERIES) {
					foreach(e; ECM.query!(QueryTypes!QUERY)()) {

						// Currently produces memory mismatch for entity at runtime, should be fixed sometime
						version(TemplateVersion) {
							template CallParameter(param) {
								static if(is(param == typeof(ECM))) {
									alias CallParameter = ECM;
								}
								else static if(is(param == Entity)) {
									alias CallParameter = e;
								}
								else {
									alias paramInfo = TemplateInfo!param;
									alias componentType = paramInfo.Arguments[0];
									auto getComponent(T)() { return e.getComponent!(T)(); }
									alias CallParameter = getComponent!componentType;
								}
							}

							alias callParameters = staticMap!(CallParameter, ParameterTypeTuple!QUERY);

							static if(is(ReturnType!QUERY == bool)) {
								if(QUERY(callParameters)) 
									ECM.deleteLater(e);
							}
							else {
								QUERY(callParameters);
							}
						}
						else {
							string GenerateCall(PARAMETERS...)() {
								string code = "";
								string entitySymbol = __traits(identifier, e);
								foreach(i, PARAMETER; PARAMETERS) {
									static if(i != 0) { code ~= ", "; }

									static if(is(PARAMETER == typeof(ECM))) {
										code ~= __traits(identifier, ECM);
									}
									else static if(is(PARAMETER == Entity)) {
										code ~= entitySymbol;
									}
									else {
										alias paramInfo = TemplateInfo!PARAMETER;
										alias componentType = paramInfo.Arguments[0];
										code ~= entitySymbol ~ ".getComponent!(" ~ componentType.stringof ~ ")()";
									}
								}
								return code;
							}

							enum queryCall = __traits(identifier, QUERY) ~ "(" ~ GenerateCall!(ParameterTypeTuple!QUERY)() ~ ");";

							static if(is(ReturnType!QUERY == bool)) {
								mixin("bool deleteEntity = " ~ queryCall);
								if(deleteEntity)
									ECM.deleteLater(e);
							}
							else {
								mixin(queryCall);
							}
						}
					}

				}

				ECM.executeDelete();
				return true;
			}
			bool autoQueryFktExecuted = AutoQueryFkt();
		}	
	}

	mixin InvokeQueries!(SystemQueries!(typeof(this)));
}

//###################################################################################################
/*
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

        void query(Qry!ComponentOne c) {
            assert(c.message == "CheckSum: ");
            c.message ~= "VC;";
        }

        void query(ECM m, Qry!ComponentOne c) {
            assert(c.message == "CheckSum: VC;");
            c.message ~= "VMC;";
        }

        void query(Entity e, Qry!ComponentOne c) {
            assert(e == Entity(0));
            assert(c.message == "CheckSum: VC;VMC;");
            c.message ~= "VEC;";
        }

        void query(ECM m, Entity e, Qry!ComponentOne c) {
            assert(e == Entity(0));
            assert(c.message == "CheckSum: VC;VMC;VEC;");
            c.message ~= "VMEC;";
        }

        void query(Qry!ComponentThree c, Qry!ComponentFour c2) {
            assert(c.message == "Check: ");
            assert(c2.message == "Sum: ");
            c.message ~= "VCC;";
            c2.message ~= "VCC;";
        }

        void query(ECM m, Qry!ComponentThree c, Qry!ComponentFour c2) {
            assert(c.message == "Check: VCC;");
            assert(c2.message == "Sum: VCC;");
            c.message ~= "VMCC;";
            c2.message ~= "VMCC;";
        }

        void query(Entity e, Qry!ComponentThree c, Qry!ComponentFour c2) {
            assert(e == Entity(2));
            assert(c.message == "Check: VCC;VMCC;");
            assert(c2.message == "Sum: VCC;VMCC;");
            c.message ~= "VECC;";
            c2.message ~= "VECC;";
        }

        void query(ECM m, Entity e, Qry!ComponentThree c, Qry!ComponentFour c2) {
            assert(e == Entity(2));
            assert(c.message == "Check: VCC;VMCC;VECC;");
            assert(c2.message == "Sum: VCC;VMCC;VECC;");
            c.message ~= "VMECC;";
            c2.message ~= "VMECC;";
        }
    }

    @System final class SystemTwo(ECM) {

        mixin AutoQuery;

        bool query(Qry!ComponentOne c) {
            assert(c.message == "CheckSum: VC;VMC;VEC;VMEC;");
            c.message ~= "2VC;";
            return false;
        }

        bool query(Qry!ComponentThree c, Qry!ComponentFour c2) {
            assert(c.message == "Check: VCC;VMCC;VECC;VMECC;");
            assert(c2.message == "Sum: VCC;VMCC;VECC;VMECC;");
            c.message ~= "2VCC;";
            c2.message ~= "2VCC;";
            return false;
        }

        bool query(Qry!ComponentTwo c) {
            assert(c.message == "DeleteThis");
            return true;
        }

        bool query(Qry!ComponentFive c, ComponentSix c2) {
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
    autoECS.ecm.executeDelete();

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
    autoECS.ecm.executeDelete();

    Entity e4 = autoECS.ecm.pushEntity(ComponentFive("Delete"), ComponentSix("This"));

    autoECS.run();

    assert(!autoECS.ecm.isValid(e));
    assert(!autoECS.ecm.isValid(e2));
    assert(!autoECS.ecm.isValid(e3));
    assert(!autoECS.ecm.isValid(e4));

    writeln("################## GEN.QUERYGEN UNITTEST STOP  ##################");
}
*/
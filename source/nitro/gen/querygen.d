/***********************************************************************************************************************
Automatically generate queries based on functions in Systems
This Module is optional and not using it is (currently) preferred.

Copyright: Copyright Felix 'Zoadian' Hufnagel 2014- and Paul Freund 2014-.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: $(WEB zoadian.de, Felix 'Zoadian' Hufnagel) and $(WEB lvl3.org, Paul Freund).
*/
module nitro.gen.querygen;

import nitro.accessor;

private template TemplateInfo( T ) {
	static if ( is( T t == U!V, alias U, V... ) ) {
		alias U Template;
		alias V Arguments;
	}
}

private template MemberFunctions(T) {
	import std.typetuple : staticMap; 
	template ToFunctionType(string functionName) {
		import std.traits : MemberFunctionsTuple;
		alias ToFunctionType = MemberFunctionsTuple!(T, functionName);
	}
	alias MemberFunctions = staticMap!(ToFunctionType, __traits(allMembers, T));
}

private auto pushEntity(ECM, ARGS...)(ECM ecm, ARGS args) {
	auto e = ecm.createEntity();
	foreach(arg;args) {
        ecm.addComponents(e, arg);
	}
    return e;
}

///
alias Qry = Accessor;

/***********************************************************************************************************************
AutoQuery
*/
mixin template AutoQuery() {
	void run(ECM)(ECM ecm) {
		mixin AutoQueryMapper!(ecm);
	}
}

/***********************************************************************************************************************
AutoQueryMapper
*/
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

version(unittest) {
	import std.stdio;
    import nitro;
    @Component struct QUERYGEN_ComponentOne { string message; }
    @Component struct QUERYGEN_ComponentTwo { string message; }
    @Component struct QUERYGEN_ComponentThree { string message; }
    @Component struct QUERYGEN_ComponentFour { string message; }

    @Component struct QUERYGEN_ComponentFive { string message; }
    @Component struct QUERYGEN_ComponentSix { string message; }

    @System final class QUERYGEN_SystemOne(ECM) {

        void run(ECM ecm) {
            mixin AutoQueryMapper!ecm;
        }

        void query1(Qry!QUERYGEN_ComponentOne c) {
            assert(c.message == "CheckSum: ");
            c.message ~= "VC;";
        }

        void query2(ECM m, Qry!QUERYGEN_ComponentOne c) {
            assert(c.message == "CheckSum: VC;");
            c.message ~= "VMC;";
        }

        void query3(Entity e, Qry!QUERYGEN_ComponentOne c) {
            assert(e == Entity(0));
            assert(c.message == "CheckSum: VC;VMC;");
            c.message ~= "VEC;";
        }

        void query4(ECM m, Entity e, Qry!QUERYGEN_ComponentOne c) {
            assert(e == Entity(0));
            assert(c.message == "CheckSum: VC;VMC;VEC;");
            c.message ~= "VMEC;";
        }

        void query5(Qry!QUERYGEN_ComponentThree c, Qry!QUERYGEN_ComponentFour c2) {
            assert(c.message == "Check: ");
            assert(c2.message == "Sum: ");
            c.message ~= "VCC;";
            c2.message ~= "VCC;";
        }

        void query6(ECM m, Qry!QUERYGEN_ComponentThree c, Qry!QUERYGEN_ComponentFour c2) {
            assert(c.message == "Check: VCC;");
            assert(c2.message == "Sum: VCC;");
            c.message ~= "VMCC;";
            c2.message ~= "VMCC;";
        }

        void query7(Qry!QUERYGEN_ComponentFour c2, Entity e, Qry!QUERYGEN_ComponentThree c) {
            assert(e == Entity(2));
            assert(c.message == "Check: VCC;VMCC;");
            assert(c2.message == "Sum: VCC;VMCC;");
            c.message ~= "VECC;";
            c2.message ~= "VECC;";
        }

        void query8(Qry!QUERYGEN_ComponentThree c, Entity e, Qry!QUERYGEN_ComponentFour c2, ECM m) {
            assert(e == Entity(2));
            assert(c.message == "Check: VCC;VMCC;VECC;");
            assert(c2.message == "Sum: VCC;VMCC;VECC;");
            c.message ~= "VMECC;";
            c2.message ~= "VMECC;";
        }
    }

    @System final class QUERYGEN_SystemTwo(ECM) {

        mixin AutoQuery;

        bool query(Qry!QUERYGEN_ComponentOne c) {
            assert(c.message == "CheckSum: VC;VMC;VEC;VMEC;");
            c.message ~= "2VC;";
            return false;
        }

        bool query(Qry!QUERYGEN_ComponentThree c, Qry!QUERYGEN_ComponentFour c2) {
            assert(c.message == "Check: VCC;VMCC;VECC;VMECC;");
            assert(c2.message == "Sum: VCC;VMCC;VECC;VMECC;");
            c.message ~= "2VCC;";
            c2.message ~= "2VCC;";
            return false;
        }

        bool query(Qry!QUERYGEN_ComponentTwo c) {
            assert(c.message == "DeleteThis");
            return true;
        }

        bool query(Qry!QUERYGEN_ComponentFive c, QUERYGEN_ComponentSix c2) {
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
	auto autoECS = makeECS!(nitro.gen.querygen)();

    Entity e = autoECS.ecm.pushEntity(QUERYGEN_ComponentOne("CheckSum: "));

    autoECS.run();

    auto component = autoECS.ecm.getComponent!QUERYGEN_ComponentOne(e);
    assert(component.message == "CheckSum: VC;VMC;VEC;VMEC;2VC;");

    autoECS.ecm.deleteLater(e);
    autoECS.ecm.executeDelete();

    Entity e2 = autoECS.ecm.pushEntity(QUERYGEN_ComponentTwo("DeleteThis"));

    autoECS.run();

    Entity e3 = autoECS.ecm.pushEntity(QUERYGEN_ComponentThree("Check: "), QUERYGEN_ComponentFour("Sum: "));

    autoECS.run();

    auto componentThree = autoECS.ecm.getComponent!QUERYGEN_ComponentThree(e3);
    auto componentFour = autoECS.ecm.getComponent!QUERYGEN_ComponentFour(e3);
    assert(componentThree.message == "Check: VCC;VMCC;VECC;VMECC;2VCC;");
    assert(componentFour.message == "Sum: VCC;VMCC;VECC;VMECC;2VCC;");

    autoECS.ecm.deleteLater(e3);
    autoECS.ecm.executeDelete();

    Entity e4 = autoECS.ecm.pushEntity(QUERYGEN_ComponentFive("Delete"), QUERYGEN_ComponentSix("This"));

    autoECS.run();

    writeln("################## GEN.QUERYGEN UNITTEST STOP  ##################");
}

/***********************************************************************************************************************
Implementation of an 'Array of Structures' and 'Structure of Arrays' Array

Copyright: Copyright Felix 'Zoadian' Hufnagel 2014- and Paul Freund 2014-.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: $(WEB zoadian.de, Felix 'Zoadian' Hufnagel) and $(WEB lvl3.org, Paul Freund).
*/
module nitro.gen.ecsgen;

import nitro.ecs;

import std.traits : fullyQualifiedName;
private enum isModule(alias T) = __traits(compiles, mixin("import " ~ fullyQualifiedName!T ~ ";"));

///Component Flag. All Component must be annotated @Component
enum Component;	  

///System Flag. All Systems must be annotated @System
enum System;

/***********************************************************************************************************************
ComponentsOfModule
*/
template ComponentsOfModule(alias MODULE) {	
	mixin("import " ~ fullyQualifiedName!MODULE ~ ";");
	template TYPE(string MEMBER_NAME) {
		static if(__traits(compiles, __traits(getMember, MODULE, MEMBER_NAME)())) {
			alias TYPE = typeof(__traits(getMember, MODULE, MEMBER_NAME)());
		}	
		else {
			alias TYPE = void;
		}
	}	
	import std.typetuple : NoDuplicates, Filter, EraseAll, staticMap, staticIndexOf;
	template isComponent(alias T) { enum isComponent = staticIndexOf!(Component, __traits(getAttributes, T)) != -1; };	  
	alias ComponentsOfModule = NoDuplicates!(Filter!(isComponent, EraseAll!(void, staticMap!(TYPE, __traits(allMembers, MODULE)))));
}	

/***********************************************************************************************************************
SystemsOfModule
*/
template SystemsOfModule(alias MODULE) {		
	mixin("import " ~ fullyQualifiedName!MODULE ~ ";");
	template TYPE(string MEMBER_NAME) {
		// Temporary solution
		static if(__traits(compiles, __traits(getMember, MODULE, MEMBER_NAME).stringof)) {
			enum MEMBER_DEFINITION = __traits(getMember, MODULE, MEMBER_NAME).stringof;
			import std.algorithm : startsWith, endsWith;
			static if(MEMBER_DEFINITION.startsWith("class ") && MEMBER_DEFINITION.endsWith("(ECM)"))
				mixin("alias TYPE ="~ MEMBER_NAME ~"!(EntityComponentManager!());");
			else 
				alias TYPE = void;
		}
		else {
			alias TYPE = void;
		}
	}	
	import std.typetuple : NoDuplicates, Filter, EraseAll, staticMap, staticIndexOf;
	template isSystem(alias T) { enum isSystem = staticIndexOf!(System, __traits(getAttributes, T)) != -1; };	
	alias SystemsOfModule = NoDuplicates!(Filter!(isSystem, EraseAll!(void, staticMap!(TYPE, __traits(allMembers, MODULE)))));  
}

/***********************************************************************************************************************
makeECS generates an ECS from Components and Systems found in modules MODULE_LIST
*/
auto makeECS(MODULE_LIST...)() {				
	import std.typetuple : TypeTuple, staticMap;	

	//static assert(allSatisfy!(isModule, MODULE_LIST), "passed a non-module");
	
	alias COMPONENTS = TypeTuple!(staticMap!(ComponentsOfModule, MODULE_LIST));
	alias SYSTEMS = TypeTuple!(staticMap!(SystemsOfModule, MODULE_LIST));

	return new SystemManager!(EntityComponentManager!COMPONENTS, SYSTEMS)();
}


//###################################################################################################

version(unittest) {
    @System final class ECSGEN_SystemOne(ECM) {
        void run(ECM ecm) {
            foreach(e; ecm.query!ECSGEN_ComponentTwo()) {
                assert(false);
            }
            foreach(e; ecm.query!ECSGEN_ComponentOne()) {
                auto component = e.getComponent!ECSGEN_ComponentOne();
                assert(component.token == "CheckpointOne");
                ecm.deleteLater!ECSGEN_ComponentOne(e);
                ecm.addComponents(e, ECSGEN_ComponentTwo("CheckpointTwo"));
            }

            ecm.executeDelete();
        }
    }


    @System final class ECSGEN_SystemTwo(ECM) {
        void run(ECM ecm) {
            foreach(e; ecm.query!ECSGEN_ComponentOne()) {
                assert(false);
            }
            foreach(e; ecm.query!ECSGEN_ComponentTwo()) {
                auto component = e.getComponent!ECSGEN_ComponentTwo();
                assert(component.token == "CheckpointTwo");
                ecm.deleteLater!ECSGEN_ComponentTwo(e);
                ecm.addComponents(e, ECSGEN_ComponentThree("CheckpointThree"));
            }
            ecm.executeDelete();
        }
    }

    @Component struct ECSGEN_ComponentOne {
        string token;
    }

    @Component struct ECSGEN_ComponentTwo {
        string token;
    }

    @Component struct ECSGEN_ComponentThree {
        string token;
    }
}

unittest {
    import std.stdio : writeln; 
    writeln("################## GEN.ECSGEN UNITTEST START ##################");

	// Test gen ecs functionality
	auto autoECS = makeECS!(nitro.gen.ecsgen, nitro.gen.querygen)();

	Entity entity = autoECS.ecm.createEntity();
    autoECS.ecm.addComponents(entity, ECSGEN_ComponentOne("CheckpointOne"));
	autoECS.run();

    foreach(e; autoECS.ecm.query!ECSGEN_ComponentOne()) {
        assert(false);
    }
    foreach(e; autoECS.ecm.query!ECSGEN_ComponentTwo()) {
        assert(false);
    }

    autoECS.ecm.executeDelete();

    writeln("################## GEN.ECSGEN UNITTEST STOP  ##################");
}

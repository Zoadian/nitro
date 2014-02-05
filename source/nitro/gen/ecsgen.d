// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.gen.ecsgen;

import nitro.ecs;

import std.typetuple;

/**			   
Component Flag. All Component must be annotated @Component
*/
enum Component;	  

/**
System Flag. All Systems must be annotated @System
*/
enum System;

/**
ModuleLookup
*/
mixin template ComponentSystemLookup() {
	/**
	ComponentsOfModule
	*/
	template ComponentsOfModule(alias M) {
		template TYPE(string MEMBER_NAME) {
			static if(__traits(compiles, __traits(getMember, M, MEMBER_NAME)())) {
				alias TYPE = typeof(__traits(getMember, M, MEMBER_NAME)());
			}	
			else {
				alias TYPE = void;
			}
		}	
		template isComponent(alias T) { enum isComponent = staticIndexOf!(Component, __traits(getAttributes, T)) != -1; };	  
		alias ComponentsOfModule = NoDuplicates!(Filter!(isComponent, EraseAll!(void, staticMap!(TYPE, __traits(allMembers, M)))));		  
		//pragma(msg, ComponentsOfModule ,M.stringof);
	}			


	/**
	SystemsOfModule
	*/
	template SystemsOfModule(alias M) {		
		template TYPE(string MEMBER_NAME) {
			// Temporary solution (hack)
			static if(__traits(compiles, __traits(getMember, M, MEMBER_NAME).stringof)) {
				enum MEMBER_DEFINITION = __traits(getMember, M, MEMBER_NAME).stringof;
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
		template isSystem(alias T) { enum isSystem = staticIndexOf!(System, __traits(getAttributes, T)) != -1; };	  
		alias SystemsOfModule = NoDuplicates!(Filter!(isSystem, EraseAll!(void, staticMap!(TYPE, __traits(allMembers, M)))));  
		//pragma(msg, SystemsOfModule);
	}			


}


/**
MakeECS
*/
mixin template MakeECS(string SYMBOL_NAME, string MODULE_LIST) {					

	mixin ComponentSystemLookup;
	string c(string s...) {
		import std.algorithm : splitter;
		auto e = s.splitter(","); 
		//gen imports
		string res = "import std.typetuple; import ";	
		foreach(k; e) {
			res ~= k ~",";
		}		   
		res.length -= 1;
		res ~= ";\n";		
		//gen components
		res ~= "alias Components = TypeTuple!(";
		foreach(k; e) {						
			res ~= "ComponentsOfModule!(" ~ k ~"),";
		}		 
		res.length -= 1;
		res ~= ");\n";
		//gen systems 
		res ~= "alias Systems = TypeTuple!(";
		foreach(k; e) {
			res ~= "SystemsOfModule!(" ~ k ~"),";
		}
		res.length -= 1;
		res ~= ");\n";

		return res;
	}
	//pragma(msg, c(MODULE_LIST));
	mixin(c(MODULE_LIST));

	alias ECS = SystemManager!(EntityComponentManager!Components, Systems);
	mixin("ECS " ~ SYMBOL_NAME ~ " = new ECS();");
}

//###################################################################################################

version(unittest) {
    @System final class SystemOne(ECM) {
        void run(ECM ecm) {
            foreach(e; ecm.query!ComponentTwo()) {
                assert(false);
            }
            foreach(e; ecm.query!ComponentOne()) {
                auto component = e.getComponent!ComponentOne();
                assert(component.token == "CheckpointOne");
                ecm.deleteLater!ComponentOne(e);
                ecm.addComponents(e, ComponentTwo("CheckpointTwo"));
            }

            ecm.deleteNow();
        }
    }


    @System final class SystemTwo(ECM) {
        void run(ECM ecm) {
            foreach(e; ecm.query!ComponentOne()) {
                assert(false);
            }
            foreach(e; ecm.query!ComponentTwo()) {
                auto component = e.getComponent!ComponentTwo();
                assert(component.token == "CheckpointTwo");
                ecm.deleteLater!ComponentTwo(e);
                ecm.addComponents(e, ComponentThree("CheckpointThree"));
            }
            ecm.deleteNow();
        }
    }

    @Component struct ComponentOne {
        string token;
    }

    @Component struct ComponentTwo {
        string token;
    }

    @Component struct ComponentThree {
        string token;
    }
}

unittest {
    import std.stdio : writeln; 
    writeln("################## GEN.ECSGEN UNITTEST START ##################");

	// Test gen ecs functionality
	mixin MakeECS!("autoECS", "nitro.gen.ecsgen");

	Entity entity = autoECS.ecm.createEntity();
    autoECS.ecm.addComponents(entity, ComponentOne("CheckpointOne"));

	autoECS.run();

    foreach(e; autoECS.ecm.query!ComponentOne()) {
        assert(false);
    }
    foreach(e; autoECS.ecm.query!ComponentTwo()) {
        assert(false);
    }
    foreach(e; autoECS.ecm.query!ComponentTwo()) {
        auto component = e.getComponent!ComponentThree();
        assert(component.token == "CheckpointThree");
        autoECS.ecm.deleteLater!ComponentThree(e);
    }

    autoECS.ecm.deleteNow();

    writeln("################## GEN.ECSGEN UNITTEST STOP  ##################");
}

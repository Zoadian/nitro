// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.autogen;

import nitro.sm;

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
		template TYPE(alias T) {
			static if(__traits(compiles, __traits(getMember, M, T)())) {
				alias TYPE = typeof(__traits(getMember, M, T)());
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
		template TYPE(alias T) {	 		  
			static if(__traits(compiles, mixin(T~"!(EntityComponentManager!())"))) {	   				
				mixin("alias TYPE ="~ T ~"!(EntityComponentManager!());");
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
mixin template MakeECS(string T) {					

	mixin ComponentSystemLookup;
	string c(string s...) {
		auto e = s.splitter(","); 
		//gen imports
		string res = "import ";	
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
	//pragma(msg, c(T));
	mixin(c(T));

	alias ECS = SystemManager!(EntityComponentManager!Components, Systems);
	ECS ecs = new ECS();
}

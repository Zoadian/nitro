// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.sm;
				   
import nitro.ecm;

import std.typetuple;


/**
SystemManager
*/
class SystemManager(ECM, ALL_SYSTEMS...) {
private:
	template TEMPLATEIZE_SYSTEM(alias T) {
		alias TEMPLATEIZE_SYSTEM = T!ECM;
	}

	alias SYSTEMS = staticMap!(TEMPLATEIZE_SYSTEM, ALL_SYSTEMS);

private:
	ECM _ecm = new ECM();
	SYSTEMS _systems;		  
	pragma(msg, "========================");
	pragma(msg, "Systems: ", SYSTEMS);
	pragma(msg, "========================");

public:	   
	/**
	*/
	this() {
		foreach(s, S; SYSTEMS) {
			static if(__traits(hasMember, S, "__ctor")) {
				_systems[s] = new S(_ecm);
			}
			else {		   
				_systems[s] = new S();
			}
		}
	}   

	/**
	*/
	~this() {
		foreach(s, S; SYSTEMS) {
			_systems[s].destroy();
		}
	}

	/**
	Runs all systems once.
	*/
	void run() {
		foreach(s; _systems) {
			s.run(_ecm);
		}
	}

	/**
	Returns requested system.
	*/		
	auto system(alias S)() {			
		enum StringOf(T) = T.stringof;
		alias IDX = staticIndexOf!(StringOf!(S!ECM), staticMap!(StringOf, ALL_SYSTEMS));
		static assert(IDX != -1, S!ECM.stringof ~ " is not part of " ~ ALL_SYSTEMS.stringof);
		return _systems[IDX];
	}
}

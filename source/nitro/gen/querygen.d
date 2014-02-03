// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel), $(WEB lvl3.org, Paul Freund)
*/
module nitro.gen.querygen;

//---------------------------------------------------------------------------------------------------

void pushEntity(ECM, ARGS...)(ECM ecm, ARGS args) {
	auto e = ecm.createEntity();
	foreach(arg;args) {
        ecm.addComponents(e, arg);
	}
}

//---------------------------------------------------------------------------------------------------
mixin template AutoQuery() {
	void run(ECM)(ECM ecm) {
		mixin AutoQueryMapper!(ecm);
	}
}

//---------------------------------------------------------------------------------------------------
mixin template AutoQueryMapper(alias ECM) {

    private template IterateQueryFkts(PARENT, LIST...) if(LIST.length > 0) {
        import std.traits : ParameterTypeTuple, ReturnType;
		import std.typetuple : staticMap; 

		alias ELEMENT = LIST[0];
		alias RETURN_TYPE = ReturnType!(ELEMENT);

		static if(is(RETURN_TYPE == void) || is(RETURN_TYPE == bool)) {
			alias ELEMENT_PARAMS = ParameterTypeTuple!(ELEMENT);
			enum ToString(T) = T.stringof;
			enum RESULT = generateAutoQueries!(ECM, is(RETURN_TYPE==bool), staticMap!(ToString, ELEMENT_PARAMS));
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

	// Start loop over all entities
	// Todo: remove array and sort from implementation once ECM is improved
	code ~= "foreach(e;" ~ ecmIdentifier ~ ".query!(" ~ typeList ~ ")()){";

	// Get all components for query
	foreach(TYPE; TYPES) {
		code ~= "auto param" ~ TYPE ~ "= e.get!" ~ TYPE ~ "();";
	}

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
		code ~= "param" ~ TYPE;
		code ~= (i < (TYPES.length-1)) ? "," : ");";
	}

	// If function returns bool, remove component if true
	// TODO: destroyEntity instead of removeComponents
	if(isBool) { code ~= "if(deleteEntity){" ~ ecmIdentifier ~ ".destroyEntity(e); }"; }

	// Close entity iteration
	code ~= "}";

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
						static assert(0, "u suck hard");
					}
				}
			}	
		}
	}
}

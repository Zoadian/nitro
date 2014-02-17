/***********************************************************************************************************************
Implementation of an Entity Component System (ECS).

Copyright: Copyright Felix 'Zoadian' Hufnagel 2014- and Paul Freund 2014-.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: $(WEB zoadian.de, Felix 'Zoadian' Hufnagel) and $(WEB lvl3.org, Paul Freund).
*/
module nitro.ecs;

public import nitro.accessor;
import std.traits : RepresentationTypeTuple;

private enum hasFields(T) = RepresentationTypeTuple!T.length != 0;

private template hasFunctions(COMPONENT) {
	enum isFunction(string T) =  __traits(compiles, FunctionTypeOf!(__traits(getMember, COMPONENT, T))) ? true : false; 
	import std.typetuple : staticMap, anySatisfy;
	alias _isFns = staticMap!(isFunction, __traits(allMembers, COMPONENT));
	enum isTrue(alias T) = T == true;
	enum hasFunctions = anySatisfy!(isTrue, _isFns);
}

private alias Make_Size_t(T) = size_t;

private template staticIota(size_t start, size_t stop)
{
	import std.typetuple : TypeTuple;
	static if (stop <= start)
		alias TypeTuple!() staticIota;
	else
		alias TypeTuple!(staticIota!(start, stop-1), stop-1) staticIota;
}

private struct ComponentArray(COMPONENT){
	Entity[] entities;
	alias getMember(alias T) = typeof(__traits(getMember, COMPONENT, T)); 
	static if(hasFields!COMPONENT) {
		AccessorArray!COMPONENT components;
	}
	
	void add(Entity entity, COMPONENT component) @trusted nothrow {
		try {
			import std.algorithm : countUntil;
			auto idx = countUntil!((a,b) => a > b)(this.entities, entity);
			if(idx != -1) {
				import std.array : insertInPlace;
				this.entities.insertInPlace(idx, entity);
				static if(hasFields!COMPONENT) {
					this.components.insertInPlace(idx, component);
				}
			}
			else {
				this.entities ~= entity;
				static if(hasFields!COMPONENT) {
					this.components ~= component;
				}
			}
		}
		catch(Exception e) {
		}
	}
	
	void remove(Entity entity) @trusted nothrow {
		try {
			import std.algorithm : countUntil;
			auto idx = this.entities.countUntil(entity);
			if(idx != -1) {
				import std.algorithm : remove, SwapStrategy;
				this.entities = this.entities.remove!(SwapStrategy.stable)(idx);
				//WARNING: this must be assigned to this.components if SOA is not used!
				static if(hasFields!COMPONENT) {
					this.components.remove!(SwapStrategy.stable)(idx);
				}
			}
		}
		catch(Exception e) {
		}
	}
	
	bool has(Entity entity) const @trusted nothrow {
		try {
			import std.algorithm : countUntil;
			auto idx = this.entities.countUntil(entity);
			return idx != -1;
		}
		catch(Exception e) {
			return false;
		}
	}

	static if(hasFields!COMPONENT) {
		Accessor!COMPONENT get(Entity entity) @trusted {
			import std.algorithm : countUntil;
			auto idx = this.entities.countUntil(entity);
			if(idx == -1) {
				throw new Exception("entity not found");
			}
			return this.components[idx];
		}
	}
	
	invariant() {
		// components must be ordered (ascending)!
		assert(this.entities.dup.sort == this.entities);
		// entity and component array must have same length!
		static if(hasFields!COMPONENT) {
			assert(this.entities.length == this.components.length);
		}

		static assert(!hasFunctions!COMPONENT, COMPONENT.stringof ~ " may not have memberfunctions!");
	}
}

/***********************************************************************************************************************
Entity
*/
struct Entity {	
private:
	size_t id;

public:
	///
	int opCmp(ref const Entity entity) const @safe nothrow {
		if(this.id < entity.id) {
			return -1;
		}
		else if(entity.id < this.id) {
			return 1;
		}		
		return 0;
	}
}

final class EntityComponentManager(COMPONENTS...) if(COMPONENTS.length == 0) {
	alias Components = COMPONENTS;
	Entity createEntity() @safe nothrow { assert(0); }
	void destroy(Entity entity) @safe nothrow { assert(0); }
	void destroyNow(Entity entity) @safe nothrow { assert(0); }
	void addComponents(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) { assert(0); }
	void addComponentsNow(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) { assert(0); }
	void removeComponents(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) { assert(0); }
	void removeComponentsNow(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) { assert(0); }
	alias clear = removeComponents!COMPONENTS;
	alias clearNow = removeComponents!COMPONENTS;
	void flush() @safe nothrow { assert(0); }
	bool hasComponents(PCS...)(Entity entity) const @safe nothrow if(PCS.length > 0) { assert(0); }
	QueryResult!(typeof(this), COMPONENTS) query(PCS...)() @safe nothrow { assert(0); }
	void _destroyEntity(Entity entity) @safe nothrow { assert(0); }
}

/***********************************************************************************************************************
EntityComponentManager
*/
final class EntityComponentManager(COMPONENTS...) if(COMPONENTS.length > 0) {
	alias Components = COMPONENTS;
	alias EntityArray(T) = Entity[];
	struct ETA(T) { Entity[] entities; T[] components; }
	import std.typetuple : staticMap;
	staticMap!(ComponentArray, COMPONENTS) _components;
	size_t _nextEntityId = 0;
	Entity[] _deleteLaterEntities;
	staticMap!(ETA, COMPONENTS) _addLaterComponents;
	staticMap!(EntityArray, COMPONENTS) _deleteLaterComponents;

	///
	invariant() {
		foreach(C; COMPONENTS) {
			static assert(!hasFunctions!C, C.stringof ~ " may not have memberfunctions!");
		}
	}

public:
	///
	Entity createEntity() @safe nothrow {
		return Entity(_nextEntityId++);
	}

	/// entity is destroyed on next flush()
	void destroy(Entity entity) @safe nothrow {
		this._deleteLaterEntities ~= entity;
	}

	/// entity is destroyed immediately	
	void destroyNow(Entity entity) @safe nothrow {
		foreach(ref c; _components) {
			c.remove(entity);
		}
	}

	/// components are added on next flush()
	void addComponents(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			import std.typetuple : staticIndexOf;
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._addLaterComponents[IDX].entities ~= entity;
			this._addLaterComponents[IDX].components ~= pcs[i];
		}
	}

	/// components are added on immediately
	void addComponentsNow(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			import std.typetuple : staticIndexOf;
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._components[IDX].add(entity, pcs[i]);
		}
	}

	/// components are removed on next flush()
	void removeComponents(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			import std.typetuple : staticIndexOf;
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._deleteLaterComponents[IDX] ~= entity;
		}
	}
	
	/// components are removed on next immediately
	void removeComponentsNow(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			import std.typetuple : staticIndexOf;
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._components[IDX].remove(entity);
		}
	}
	
	/// all components are removed on next flush()
	alias clear = removeComponents!COMPONENTS;
	
	/// all components are removed on next immediately
	alias clearNow = removeComponents!COMPONENTS;

	/// executes all buffered operations
	void flush() @safe nothrow {
		//destroy entities
		foreach(e; _deleteLaterEntities) {
			this.destroyNow(e);
		}
		this._deleteLaterEntities.clear();
		//destroy components
		foreach(i, PC; COMPONENTS) {
			foreach(e; _deleteLaterComponents[i]) {
				this.removeComponentsNow!PC(e);
			}
			this._deleteLaterComponents[i].clear();
		}		
		//add components
		foreach(i, PC; COMPONENTS) {
			foreach(k, e; _addLaterComponents[i].entities) {
				this.addComponentsNow!PC(e, _addLaterComponents[i].components[k]);
			}
			this._addLaterComponents[i].entities.clear();
			this._addLaterComponents[i].components.clear();
		}	
	}

	/// immediately
	bool hasComponents(PCS...)(Entity entity) const @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			import std.typetuple : staticIndexOf;
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			if(this._components[IDX].has(entity) == false) {
				return false;
			}
		}
		return true;
	}

	/// immediately
	Accessor!PC getComponent(PC)(Entity entity) @safe {
		import std.typetuple : staticIndexOf;
		enum IDX = staticIndexOf!(PC, COMPONENTS);
		static assert(IDX != -1, "not fou");
		return this._components[IDX].get(entity);
	}

	/// immediately
	QueryResult!(typeof(this), PCS) query(PCS...)() @safe nothrow if(PCS.length > 0) {
		return QueryResult!(typeof(this), PCS)(this);
	}
}

struct QueryResult(ECS, PCS...) if(PCS.length == 0) {
private:
	this(ECS ecs) @safe nothrow { assert(0); }

public:
	EntityResult!(ECS, PCS) front() @safe nothrow { assert(0); }
	void popFront() @safe nothrow { assert(0); }
	bool empty() const @safe nothrow { assert(0); }
}

/***********************************************************************************************************************
QueryResult
*/
struct QueryResult(ECS, PCS...) if(PCS.length > 0 && PCS.length <= ECS.Components.length) {
	ECS _ecs;
	
	EntityResult!(ECS, PCS)[] _lookup;
	
	invariant() {
		// entities must be ordered (ascending)!
		//assert(this._lookup.dup.sort == this._lookup);
	}

private:
	this(ECS ecs) @safe nothrow {
		this._ecs = ecs;
		this._doLinearLookup();
	}

public:
	///
	EntityResult!(ECS, PCS) front() @safe nothrow {
		return _lookup[0];
	}

	///
	void popFront() @safe nothrow {
		import std.range : popFront;
		this._lookup.popFront();
	}

	///
	bool empty() const @safe nothrow {
		import std.range : empty;
		return this._lookup.empty;
	}
	
private:	
	// O(m+n)
	// see http://codercareer.blogspot.de/2011/11/no-24-intersection-of-sorted-arrays.html
	void _doLinearLookup() @trusted {
		static if(PCS.length == 1) {
			import std.typetuple : staticIndexOf;
			enum IDX_C = staticIndexOf!(PCS, ECS.Components);
			foreach(i, e; _ecs._components[IDX_C].entities) {
				this._lookup ~= EntityResult!(ECS, PCS)(_ecs, i);
			}
		}
		else {
			import std.typetuple : staticMap;
			staticMap!(Make_Size_t, PCS) indices;
			
			bool checkEnd() @safe nothrow {
				foreach(i, P; PCS) {
					import std.typetuple : staticIndexOf;
					enum IDX_C = staticIndexOf!(P, ECS.Components);
					if(indices[i] >=  this._ecs._components[IDX_C].entities.length) {
						return false;
					}
				}
				return true;
			}
			
			bool checkEqual() @safe nothrow {
				foreach(i; staticIota!(1, PCS.length)) {
					import std.typetuple : staticIndexOf;
					enum IDX_CA = staticIndexOf!(PCS[0], ECS.Components);
					enum IDX_CB = staticIndexOf!(PCS[i], ECS.Components);
					if(_ecs._components[IDX_CA].entities[indices[0]] != _ecs._components[IDX_CB].entities[indices[i]]) {
						return false;
					}
				}
				return true;
			}
			
			while(checkEnd()) {
				if(checkEqual()) {
					this._lookup ~= EntityResult!(ECS, PCS)(_ecs, indices);
					foreach(ref idx; indices) {
						++idx;
					}
				}
				else {
					//increment index of lowest entity
					size_t* pIdx = &indices[0];
					foreach(i; staticIota!(1, PCS.length)) {
						import std.typetuple : staticIndexOf;
						enum IDX_CA = staticIndexOf!(PCS[i], ECS.Components);
						enum IDX_CB = staticIndexOf!(PCS[i -  1], ECS.Components);
						if(_ecs._components[IDX_CA].entities[indices[i]] < _ecs._components[IDX_CB].entities[indices[i - 1]]) {
							pIdx = &indices[i];
						}
					}
					++(*pIdx);
				}
			}
		}
	}
}

/***********************************************************************************************************************
EntityResult dummy
*/
struct EntityResult(ECS, PCS...) if(PCS.length == 0) {
private:
	this(IDX_TS...)(ECS ecs, IDX_TS indices) @safe nothrow { assert(0); }

public:
	alias entity this;
	Accessor!COMPONENT get(COMPONENT)() @safe nothrow { assert(0); }
	alias getComponent = get;
	Entity entity() const @safe nothrow { assert(0); }
	void addComponents(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) { assert(0); }
	void addComponentsNow(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) { assert(0); }
	void removeComponents(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) { assert(0); }
	void removeComponentsNow(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) { assert(0); }
	void destroy() @safe nothrow { assert(0); }
	void destroyNow() @safe nothrow { assert(0); }
}

/***********************************************************************************************************************
EntityResult
*/
struct EntityResult(ECS, PCS...) if(PCS.length > 0) {
	enum is_size_t(T) = is(T == size_t);
	
	ECS _ecs;
	import std.typetuple : staticMap;
	staticMap!(Make_Size_t, PCS) _indices;

private:
	import std.typetuple : allSatisfy;
	this(IDX_TS...)(ECS ecs, IDX_TS indices) @safe nothrow if(allSatisfy!(is_size_t, IDX_TS)) {
		this._ecs = ecs;
		
		static assert(indices.length == IDX_TS.length);
		foreach(i, TK; IDX_TS) {
			this._indices[i] = indices[i];
		}
	}

public:
	///
	alias entity this;

	///
	Accessor!COMPONENT getComponent(COMPONENT)() @safe nothrow {
		static if(!hasFields!COMPONENT) { 
			static assert(false, "Can not access " ~COMPONENT.stringof ~". It has no fields"); 
		}
		import std.typetuple : staticIndexOf;
		enum IDX_C = staticIndexOf!(COMPONENT, ECS.Components);
		enum IDX_I = staticIndexOf!(COMPONENT, PCS);

		static if(IDX_C != -1 && IDX_I != -1) {
			return this._ecs._components[IDX_C].components[_indices[IDX_I]];
		}
		else {
			static assert(false, "no such component: " ~ COMPONENT.stringof ~ ". Available are: " ~ PCS.stringof);
		}
	}

	///
	Entity entity() const @safe nothrow {
		import std.typetuple : staticIndexOf;
		enum IDX = staticIndexOf!(PCS[0], ECS.Components);
		return this._ecs._components[IDX].entities[_indices[0]];
	}	

	///
	void addComponents(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) {
		this._ecs.addComponents(PCS)(entity, pcs);
	}
	
	///
	void addComponentsNow(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) {
		this._ecs.addComponentsNow(PCS)(entity, pcs);
	}

	///
	void removeComponents(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) {
		this._ecs.removeComponents(PCS)(entity);
	}

	///
	void removeComponentsNow(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) {
		this._ecs.removeComponentsNow(PCS)(entity);
	}

	///
	void destroy() @safe nothrow {
		this._ecs.destroy(entity);
	}
	
	///
	void destroyNow() @safe nothrow {
		this._ecs.destroyNow(entity);
	}
}

/***********************************************************************************************************************
SystemManager
*/
final class SystemManager(ECM, ALL_SYSTEMS...) {
private:
	template TEMPLATEIZE_SYSTEM(alias T) {
		alias TEMPLATEIZE_SYSTEM = T!ECM;
	}
	import std.typetuple : staticMap;
	alias SYSTEMS = staticMap!(TEMPLATEIZE_SYSTEM, ALL_SYSTEMS);
	
private:
	ECM _ecm = new ECM();
	SYSTEMS _systems;
	
public:
	///
	this() {
		foreach(s, S; SYSTEMS) {

			static if(__traits(hasMember, S, "__ctor")) {
				import std.traits : ParameterTypeTuple;
				alias PARAMETER_LIST = ParameterTypeTuple!(S.__ctor);
				static if(PARAMETER_LIST.length == 1 && is(PARAMETER_LIST[0] == ECM))
					_systems[s] = new S(_ecm);
				else static if(PARAMETER_LIST.length == 0 )
					_systems[s] = new S();
				else
					static assert("Systems can only have constructors of type this() and this(ECM)");
			}
			else {		   
				_systems[s] = new S();
			}
		}
	}

	///
	~this() {
		foreach(s, S; SYSTEMS) {
			_systems[s].destroy();
		}
	}

	/**
	Runs all systems in order of ALL_SYSTEMS
	*/
	void run() {
		foreach(s; _systems) {
			s.run(_ecm);
		}
	}

	/**
	Get the EntityComponentManager from this SystemManager
	*/
	@property ECM ecm() {
		return _ecm;
	}

	/**
	Returns requested system.
	*/	
	auto system(alias S)() @safe nothrow {		
		enum StringOf(T) = T.stringof;
		import std.typetuple : staticIndexOf;
		alias IDX = staticIndexOf!(StringOf!(S!ECM), staticMap!(StringOf, SYSTEMS));
		static assert(IDX != -1, S!ECM.stringof ~ " is not part of " ~ SYSTEMS.stringof);
		return _systems[IDX];
	}
}







//###################################################################################################
version(unittest) {
    static bool bCheckSystemOneConstructor = false;
    static bool bCheckSystemTwoConstructor = false;

    static int runCountSystemOne = 0;
    static int runCountSystemTwo = 0;

    final class SystemOne(ECM) {
        string _nextEntityIdentifier;

        this() {
            _nextEntityIdentifier = "SystemOne";
            bCheckSystemOneConstructor = true;
        }

        void run(ECM ecm) {
            runCountSystemOne++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!ComponentThree()) {
                assert(runCountSystemOne == 2);
                countComponentThreeFound++;

                ecm.removeComponents!ComponentThree(e);
				ecm.destroy(e);

				ecm.addComponentsNow(ecm.createEntity(), ComponentOne(10,"a",true), ComponentThree());
				ecm.addComponentsNow(ecm.createEntity(), ComponentTwo(11,"b",false), ComponentThree());
            }

            if(runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 1); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }

			ecm.flush();
        }
    }

    final class SystemTwo(ECM) {
        ECM _ecm;
        string _nextEntityIdentifier;

        this(ECM ecm) {
            _nextEntityIdentifier = "SystemTwo";
            _ecm = ecm;
            bCheckSystemTwoConstructor = true;
        }

        void run(ECM ecm) {
            runCountSystemTwo++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!ComponentThree()) {
                assert(runCountSystemOne == 2);
                countComponentThreeFound++;
                ecm.clear(e);
            }

            if(runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 2); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }


			ecm.flush();
        }
    }

    struct ComponentOne {
        int FieldOne;
        string FieldTwo;
        bool FieldThree;
    }

    struct ComponentTwo { 
        int FieldOne;
        string FieldTwo;
        bool FieldThree;
    }
	
	struct ComponentThree {
		int a;
	}
	
	struct ComponentFour {
	}
}

unittest {
	import std.typetuple : TypeTuple;
    import std.stdio : writeln; 
    writeln("################## ECS UNITTEST START ##################");

	alias TEST_SYSTEMS = TypeTuple!(SystemOne, SystemTwo);
	alias TEST_COMPONENTS = TypeTuple!(ComponentOne, ComponentTwo, ComponentThree, ComponentFour);

	alias TEST_ECM = EntityComponentManager!(TEST_COMPONENTS);
	alias TEST_ECS = SystemManager!(TEST_ECM, TEST_SYSTEMS);

	// Test system functions
	TEST_ECS test_ecs = new TEST_ECS();

    assert(bCheckSystemOneConstructor);
    assert(bCheckSystemTwoConstructor);

	auto system_one = test_ecs.system!SystemOne();
	auto system_two = test_ecs.system!SystemTwo();

    assert(system_one._nextEntityIdentifier == "SystemOne");
    assert(system_two._nextEntityIdentifier == "SystemTwo");

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


	test_ecm.destroy(entity_three);
	test_ecm.flush();

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponentsNow(entity_one, ComponentOne(1, "hi", true));

	assert(test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one)); 
	assert(!test_ecm.hasComponents!ComponentOne(entity_two)); 
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two)); 

	assert(!test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_one));

	test_ecm.removeComponents!ComponentOne(entity_one);
	test_ecm.flush();

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponentsNow(entity_two, ComponentOne(2, "ho", false));
	test_ecm.addComponentsNow(entity_two, ComponentTwo(3, "lets", true));

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!ComponentOne(entity_two));
	assert(test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponentsNow(entity_one, ComponentOne(4, "go", false));
	test_ecm.addComponentsNow(entity_one, ComponentTwo(5, "this", true));

	assert(test_ecm.hasComponents!ComponentOne(entity_one));
	assert(test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!ComponentOne(entity_two));
	assert(test_ecm.hasComponents!ComponentTwo(entity_two));

	assert(test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_one));
	assert(test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_two));

	auto component_one = test_ecm.getComponent!ComponentOne(entity_one);
    assert(component_one.FieldOne == 4 && component_one.FieldTwo == "go" && component_one.FieldThree == false);

	Entity entity_four = test_ecm.createEntity();
	test_ecm.addComponentsNow(entity_four, ComponentOne(6, "is", false));
	test_ecm.addComponentsNow(entity_four, ComponentTwo(6, "my", true));
    test_ecm.destroy(entity_four);

	Entity lastEntity = Entity(size_t.max);
    int currentIteration = 1;
	foreach(e; test_ecm.query!(ComponentOne, ComponentTwo)()) {
        assert(currentIteration <= 3);

		auto component = e.getComponent!ComponentOne();
		Entity en = cast(Entity)e;
        if(currentIteration == 1) { assert(en.id == 0 && component.FieldOne == 4 && component.FieldTwo == "go" && component.FieldThree == false); }
        if(currentIteration == 2) { assert(en.id == 1 && component.FieldOne == 2 && component.FieldTwo == "ho" && component.FieldThree == false); }
        if(currentIteration == 3) { assert(en.id == 3 && component.FieldOne == 6 && component.FieldTwo == "is" && component.FieldThree == false); }

		auto componenttwo = e.getComponent!ComponentTwo();
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

	test_ecm.removeComponents!ComponentTwo(entity_one);
	test_ecm.removeComponents!ComponentOne(entity_two);
	test_ecm.flush();

    int currentIterationTwo = 1;
	foreach(e; test_ecm.query!ComponentOne()) {
        assert(currentIterationTwo <= 2);

		auto component = e.getComponent!ComponentOne();
		Entity en = e;
        if(currentIterationTwo == 1) { assert(en.id == 0 && component.FieldOne == 4 && component.FieldTwo == "go" && component.FieldThree == false); }
        if(currentIterationTwo == 2) { assert(en.id == 1 && component.FieldOne == 3 && component.FieldTwo == "lets" && component.FieldThree == true); }
        currentIterationTwo++;
	}

    int currentIterationThree = 1;
	foreach(e; test_ecm.query!ComponentTwo()) {
        assert(currentIterationThree <= 1);
		auto component = e.getComponent!ComponentTwo();
		Entity en = e;
        if(currentIterationThree == 1) { assert(en.id == 1 && component.FieldOne == 3 && component.FieldTwo == "lets" && component.FieldThree == true); }
        currentIterationThree++;
	}

	assert(test_ecm.hasComponents!ComponentOne(entity_one)) ;
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(test_ecm.hasComponents!ComponentTwo(entity_two)) ;

	test_ecm.removeComponents!ComponentOne(entity_one);
	test_ecm.removeComponents!ComponentTwo(entity_two);
	test_ecm.flush();

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.destroy(entity_one);
	test_ecm.destroy(entity_two);
	test_ecm.flush();

	Entity entity_emitter = test_ecm.createEntity();
	test_ecm.addComponentsNow(entity_emitter, ComponentThree());

	test_ecs.run();
    assert(runCountSystemOne == 2);
    assert(runCountSystemTwo == 2);

	test_ecs.run();
    assert(runCountSystemOne == 3);
    assert(runCountSystemTwo == 3);

    writeln("################## ECS UNITTEST STOP  ##################");
}

//###################################################################################################

version(unittest) {
    static bool AoS_bCheckSystemOneConstructor = false;
    static bool AoS_bCheckSystemTwoConstructor = false;

    static int AoS_runCountSystemOne = 0;
    static int AoS_runCountSystemTwo = 0;

    final class AoS_SystemOne(ECM) {
        string _nextEntityIdentifier;

        this() {
            _nextEntityIdentifier = "SystemOne";
            AoS_bCheckSystemOneConstructor = true;
        }

        void run(ECM ecm) {
            AoS_runCountSystemOne++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!AoS_ComponentThree()) {
                assert(AoS_runCountSystemOne == 2);
                countComponentThreeFound++;

				ecm.removeComponents!AoS_ComponentThree(e);
                ecm.destroy(e);

				ecm.addComponentsNow(ecm.createEntity(), AoS_ComponentOne(10,"a",true), AoS_ComponentThree());
				ecm.addComponentsNow(ecm.createEntity(), AoS_ComponentTwo(11,"b",false), AoS_ComponentThree());
            }

            if(AoS_runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 1); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }

			ecm.flush();
        }
    }

    final class AoS_SystemTwo(ECM) {
        ECM _ecm;
        string _nextEntityIdentifier;

        this(ECM ecm) {
            _nextEntityIdentifier = "SystemTwo";
            _ecm = ecm;
            AoS_bCheckSystemTwoConstructor = true;
        }

        void run(ECM ecm) {
            AoS_runCountSystemTwo++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!AoS_ComponentThree()) {
                assert(AoS_runCountSystemOne == 2);
                countComponentThreeFound++;
                ecm.clear(e);
            }

            if(AoS_runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 2); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }


			ecm.flush();
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

	alias TEST_SYSTEMS = TypeTuple!(AoS_SystemOne, AoS_SystemTwo);
	alias TEST_COMPONENTS = TypeTuple!(AoS_ComponentOne, AoS_ComponentTwo, AoS_ComponentThree, AoS_ComponentFour);

	alias TEST_ECM = EntityComponentManager!(TEST_COMPONENTS);
	alias TEST_ECS = SystemManager!(TEST_ECM, TEST_SYSTEMS);

	// Test system functions
	TEST_ECS test_ecs = new TEST_ECS();

    assert(AoS_bCheckSystemOneConstructor);
    assert(AoS_bCheckSystemTwoConstructor);

	auto system_one = test_ecs.system!AoS_SystemOne();
	auto system_two = test_ecs.system!AoS_SystemTwo();

    assert(system_one._nextEntityIdentifier == "SystemOne");
    assert(system_two._nextEntityIdentifier == "SystemTwo");

    assert(AoS_runCountSystemOne == 0);
    assert(AoS_runCountSystemTwo == 0);

	test_ecs.run();

    assert(AoS_runCountSystemOne == 1);
    assert(AoS_runCountSystemTwo == 1);

	// Test entity/component functions
	auto test_ecm = test_ecs.ecm;

	Entity entity_one = test_ecm.createEntity();
	Entity entity_two = test_ecm.createEntity();
	Entity entity_three = test_ecm.createEntity();


	test_ecm.destroy(entity_three);
	test_ecm.flush();

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.addComponentsNow(entity_one, AoS_ComponentOne(1, "hi", true));

	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one)); 
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two)); 
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two)); 

	assert(!test_ecm.hasComponents!(AoS_ComponentOne,AoS_ComponentTwo)(entity_one));

	test_ecm.removeComponents!AoS_ComponentOne(entity_one);
	test_ecm.flush();

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.addComponentsNow(entity_two, AoS_ComponentOne(2, "ho", false));
	test_ecm.addComponentsNow(entity_two, AoS_ComponentTwo(3, "lets", true));

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.addComponentsNow(entity_one, AoS_ComponentOne(4, "go", false));
	test_ecm.addComponentsNow(entity_one, AoS_ComponentTwo(5, "this", true));

	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	assert(test_ecm.hasComponents!(AoS_ComponentOne,AoS_ComponentTwo)(entity_one));
	assert(test_ecm.hasComponents!(AoS_ComponentOne,AoS_ComponentTwo)(entity_two));

	auto component_one = test_ecm.getComponent!AoS_ComponentOne(entity_one);
    assert(component_one.FieldOne == 4 && component_one.FieldTwo == "go" && component_one.FieldThree == false);

	Entity entity_four = test_ecm.createEntity();
	test_ecm.addComponentsNow(entity_four, AoS_ComponentOne(6, "is", false));
	test_ecm.addComponentsNow(entity_four, AoS_ComponentTwo(6, "my", true));
    test_ecm.destroy(entity_four);

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

	test_ecm.removeComponents!AoS_ComponentTwo(entity_one);
	test_ecm.removeComponents!AoS_ComponentOne(entity_two);
	test_ecm.flush();

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

	test_ecm.removeComponents!AoS_ComponentOne(entity_one);
	test_ecm.removeComponents!AoS_ComponentTwo(entity_two);
	test_ecm.flush();

	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!AoS_ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!AoS_ComponentTwo(entity_two));

	test_ecm.destroy(entity_one);
	test_ecm.destroy(entity_two);
	test_ecm.flush();

	Entity entity_emitter = test_ecm.createEntity();
	test_ecm.addComponentsNow(entity_emitter, AoS_ComponentThree());

	test_ecs.run();
    assert(AoS_runCountSystemOne == 2);
    assert(AoS_runCountSystemTwo == 2);

	test_ecs.run();
    assert(AoS_runCountSystemOne == 3);
    assert(AoS_runCountSystemTwo == 3);

    writeln("################## AOS UNITTEST STOP  ##################");
}

//###################################################################################################

module nitro.ecs;
import std.typetuple;
import std.stdio;
import std.algorithm;
import std.range;
import std.traits;

public import nitro.soa;

struct Entity {	
private:
	size_t id;
	
	int opCmp(ref const Entity entity) const @safe nothrow {
		if(this.id < entity.id)
			return -1;
		else if(entity.id < this.id)
			return 1;
		
		return 0;
	}
}

enum hasFields(T) = RepresentationTypeTuple!T.length != 0;

template hasFunctions(COMPONENT) {
	private enum isFunction(string T) =  __traits(compiles, FunctionTypeOf!(__traits(getMember, COMPONENT, T))) ? true : false; 
	private alias _isFns = staticMap!(isFunction, __traits(allMembers, COMPONENT));
	private enum isTrue(alias T) = T == true;
	enum hasFunctions = anySatisfy!(isTrue, _isFns);
}

struct ComponentArray(COMPONENT){
	Entity[] entities;
	alias getMember(alias T) = typeof(__traits(getMember, COMPONENT, T)); 
	static if(hasFields!COMPONENT) {
		SoAArray!COMPONENT components;
	}
	
	void add(Entity entity, COMPONENT component) @trusted nothrow {
		try {
			auto idx = countUntil!((a,b) => a > b)(this.entities, entity);
			if(idx != -1) {
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
			auto idx = this.entities.countUntil(entity);
			if(idx != -1) {
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
			auto idx = this.entities.countUntil(entity);
			return idx != -1;
		}
		catch(Exception e) {
			return false;
		}
	}

	static if(hasFields!COMPONENT) {
		Accessor!COMPONENT get(Entity entity) @trusted {
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



class EntityComponentManager(COMPONENTS...) if(COMPONENTS.length == 0) {
	alias Components = COMPONENTS;
	Entity createEntity() @safe nothrow { assert(0); }
	void deleteLater(Entity entity) @safe nothrow { assert(0); }
	void deleteLater(PCS...)(Entity entity) @safe nothrow {assert(0); }
	alias clearLater = deleteLater!COMPONENTS;
	void executeDelete() { assert(0); }
	void addComponents(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) { assert(0); }
	void removeComponents(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) { assert(0); }
	bool hasComponents(PCS...)(Entity entity) const @safe nothrow if(PCS.length > 0) { assert(0); }
	Accessor!PC getComponent(PC)(Entity entity) @safe { assert(0); }
	QueryResult!(typeof(this), COMPONENTS) query(PCS...)() @safe nothrow { assert(0); }
	void _destroyEntity(Entity entity) @safe nothrow { assert(0); }
}

class EntityComponentManager(COMPONENTS...) if(COMPONENTS.length > 0) {
	alias Components = COMPONENTS;
	alias EntityArray(T) = Entity[];
	staticMap!(ComponentArray, COMPONENTS) _components;
	size_t _id = 0;

	invariant() {
		foreach(C; COMPONENTS) {
			static assert(!hasFunctions!C, C.stringof ~ " may not have memberfunctions!");
		}
	}

public:
	Entity[] _deleteLaterntities;
	staticMap!(EntityArray, COMPONENTS) _deleteLaterComponents;
		
	Entity createEntity() @safe nothrow {
		return Entity(_id++);
	}
	
	void deleteLater(Entity entity) @safe nothrow {
		this._deleteLaterntities ~= entity;
	}
	
	void deleteLater(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._deleteLaterComponents[IDX] ~= entity;
		}
	}
	
	alias clearLater = deleteLater!COMPONENTS;
	
	void executeDelete() {
		foreach(e; _deleteLaterntities) {
			this._destroyEntity(e);
		}
		_deleteLaterntities.clear();
		foreach(i, PC; COMPONENTS) {
			foreach(e; _deleteLaterComponents[i]) {
				this._components[i].remove(e);
			}
			_deleteLaterComponents[i].clear();
		}		
	}
	
	void addComponents(PCS...)(Entity entity, PCS pcs) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._components[IDX].add(entity, pcs[i]);
		}
	}
	
	void removeComponents(PCS...)(Entity entity) @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			this._components[IDX].remove(entity);
		}
	}
	
	bool hasComponents(PCS...)(Entity entity) const @safe nothrow if(PCS.length > 0) {
		foreach(i, PC; PCS) {
			enum IDX = staticIndexOf!(PC, COMPONENTS);
			if(this._components[IDX].has(entity) == false) {
				return false;
			}
		}
		return true;
	}

	Accessor!PC getComponent(PC)(Entity entity) @safe {
		enum IDX = staticIndexOf!(PC, COMPONENTS);
		static assert(IDX != -1, "not fou");
		return this._components[IDX].get(entity);
	}
	
	QueryResult!(typeof(this), PCS) query(PCS...)() @safe nothrow if(PCS.length > 0) {
		return QueryResult!(typeof(this), PCS)(this);
	}
	
private:		
	void _destroyEntity(Entity entity) @safe nothrow {
		foreach(ref c; _components) {
			c.remove(entity);
		}
	}
}

private alias Make_Size_t(T) = size_t;


template staticIota(size_t start, size_t stop)
{
	static if (stop <= start)
		alias TypeTuple!() staticIota;
	else
		alias TypeTuple!(staticIota!(start, stop-1), stop-1) staticIota;
}


struct QueryResult(ECS, PCS...) if(PCS.length == 0) {
	this(ECS ecs) @safe nothrow { assert(0); }
	EntityResult!(ECS, PCS) front() @safe nothrow { assert(0); }
	void popFront() @safe nothrow { assert(0); }
	bool empty() const @safe nothrow { assert(0); }
}

struct QueryResult(ECS, PCS...) if(PCS.length > 0 && PCS.length <= ECS.Components.length) {
	ECS _ecs;
	
	EntityResult!(ECS, PCS)[] _lookup;
	
	invariant() {
		// entities must be ordered (ascending)!
		//assert(this._lookup.dup.sort == this._lookup);
	}

public:
	this(ECS ecs) @safe nothrow {
		this._ecs = ecs;
		this._doLinearLookup();
	}
	
	EntityResult!(ECS, PCS) front() @safe nothrow {
		return _lookup[0];
	}
	
	void popFront() @safe nothrow {
		this._lookup.popFront();
	}
	
	bool empty() const @safe nothrow {
		return this._lookup.empty;
	}
	
private:	
	// O(m+n)
	// see http://codercareer.blogspot.de/2011/11/no-24-intersection-of-sorted-arrays.html
	void _doLinearLookup() @trusted {
		static if(PCS.length == 1) {
			enum IDX_C = staticIndexOf!(PCS, ECS.Components);
			foreach(i, e; _ecs._components[IDX_C].entities) {
				this._lookup ~= EntityResult!(ECS, PCS)(_ecs, i);
			}
		}
		else {
			staticMap!(Make_Size_t, PCS) indices;
			
			bool checkEnd() @safe nothrow {
				foreach(i, P; PCS) {
					enum IDX_C = staticIndexOf!(P, ECS.Components);
					if(indices[i] >=  this._ecs._components[IDX_C].entities.length) {
						return false;
					}
				}
				return true;
			}
			
			bool checkEqual() @safe nothrow {
				foreach(i; staticIota!(1, PCS.length)) {
					enum IDX_C_A = staticIndexOf!(PCS[0], ECS.Components);
					enum IDX_C_B = staticIndexOf!(PCS[i], ECS.Components);
					if(_ecs._components[IDX_C_A].entities[indices[0]] != _ecs._components[IDX_C_B].entities[indices[i]]) {
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
						enum IDX_C_A = staticIndexOf!(PCS[i], ECS.Components);
						enum IDX_C_B = staticIndexOf!(PCS[i -  1], ECS.Components);
						if(_ecs._components[IDX_C_A].entities[indices[i]] < _ecs._components[IDX_C_B].entities[indices[i - 1]]) {
							pIdx = &indices[i];
						}
					}
					++(*pIdx);
				}
			}
		}
	}
}


struct EntityResult(ECS, PCS...) if(PCS.length == 0) {
	alias entity this;
	this(IDX_TS...)(ECS ecs, IDX_TS indices) @safe nothrow { assert(0); }
	Accessor!COMPONENT get(COMPONENT)() @safe nothrow { assert(0); }
	alias getComponent = get;
	Entity entity() const @safe nothrow { assert(0); }
	void deleteLater() @safe nothrow { assert(0); }
}

struct EntityResult(ECS, PCS...) if(PCS.length > 0) {
	enum is_size_t(T) = is(T == size_t);
	
	ECS _ecs;
	staticMap!(Make_Size_t, PCS) _indices;

public:
	alias entity this;
	
	this(IDX_TS...)(ECS ecs, IDX_TS indices) @safe nothrow if(allSatisfy!(is_size_t, IDX_TS)) {
		this._ecs = ecs;
		
		static assert(indices.length == IDX_TS.length);
		foreach(i, TK; IDX_TS) {
			this._indices[i] = indices[i];
		}
	}
	
	Accessor!COMPONENT get(COMPONENT)() @safe nothrow {
		static if(!hasFields!COMPONENT) { static assert(false, "Can not access " ~COMPONENT.stringof ~". It has no fields"); }
		enum IDX_C = staticIndexOf!(COMPONENT, ECS.Components);
		enum IDX_I = staticIndexOf!(COMPONENT, PCS);

		static if(IDX_C != -1 && IDX_I != -1) {
			return this._ecs._components[IDX_C].components[_indices[IDX_I]];
		}
		else {
			static assert(false, "no such component: " ~ COMPONENT.stringof ~ ". Available are: " ~ PCS.stringof);
		}
	}
	
	alias getComponent = get;
	
	Entity entity() const @safe nothrow {
		enum IDX = staticIndexOf!(PCS[0], ECS.Components);
		return this._ecs._components[IDX].entities[_indices[0]];
	}
	
	void deleteLater() @safe nothrow {
		this._ecs.deleteLater(entity);
	}
}



/****************************************************************
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
	
public:
	/************************************************************
	*/
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

	/************************************************************
	*/
	~this() {
		foreach(s, S; SYSTEMS) {
			_systems[s].destroy();
		}
	}

	/************************************************************
	Runs all systems once.
	*/
	void run() {
		foreach(s; _systems) {
			s.run(_ecm);
		}
	}

	/************************************************************
	*/
	@property ECM ecm() {
		return _ecm;
	}

	/************************************************************
	Returns requested system.
	*/	
	auto system(alias S)() @safe nothrow {		
		enum StringOf(T) = T.stringof;
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
        string _identifier;

        this() {
            _identifier = "SystemOne";
            bCheckSystemOneConstructor = true;
        }

        void run(ECM ecm) {
            runCountSystemOne++;

            int countComponentThreeFound = 0;
            foreach(e; ecm.query!ComponentThree()) {
                assert(runCountSystemOne == 2);
                countComponentThreeFound++;

                ecm.deleteLater!ComponentThree(e);
                ecm.deleteLater(e);

                ecm.addComponents(ecm.createEntity(), ComponentOne(10,"a",true), ComponentThree());
                ecm.addComponents(ecm.createEntity(), ComponentTwo(11,"b",false), ComponentThree());
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
            foreach(e; ecm.query!ComponentThree()) {
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

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponents(entity_one, ComponentOne(1, "hi", true));

	assert(test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one)); 
	assert(!test_ecm.hasComponents!ComponentOne(entity_two)); 
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two)); 

	assert(!test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_one));

	test_ecm.deleteLater!ComponentOne(entity_one);
	test_ecm.executeDelete();

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponents(entity_two, ComponentOne(2, "ho", false));
	test_ecm.addComponents(entity_two, ComponentTwo(3, "lets", true));

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!ComponentOne(entity_two));
	assert(test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponents(entity_one, ComponentOne(4, "go", false));
	test_ecm.addComponents(entity_one, ComponentTwo(5, "this", true));

	assert(test_ecm.hasComponents!ComponentOne(entity_one));
	assert(test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(test_ecm.hasComponents!ComponentOne(entity_two));
	assert(test_ecm.hasComponents!ComponentTwo(entity_two));

	assert(test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_one));
	assert(test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_two));

	auto component_one = test_ecm.getComponent!ComponentOne(entity_one);
    assert(component_one.FieldOne == 4 && component_one.FieldTwo == "go" && component_one.FieldThree == false);

	Entity entity_four = test_ecm.createEntity();
	test_ecm.addComponents(entity_four, ComponentOne(6, "is", false));
	test_ecm.addComponents(entity_four, ComponentTwo(6, "my", true));
    test_ecm.deleteLater(entity_four);

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

	test_ecm.deleteLater!ComponentTwo(entity_one);
	test_ecm.deleteLater!ComponentOne(entity_two);
	test_ecm.executeDelete();

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

	test_ecm.deleteLater!ComponentOne(entity_one);
	test_ecm.deleteLater!ComponentTwo(entity_two);
	test_ecm.executeDelete();

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.deleteLater(entity_one);
	test_ecm.deleteLater(entity_two);
	test_ecm.executeDelete();

	Entity entity_emitter = test_ecm.createEntity();
	test_ecm.addComponents(entity_emitter, ComponentThree());

	test_ecs.run();
    assert(runCountSystemOne == 2);
    assert(runCountSystemTwo == 2);

	test_ecs.run();
    assert(runCountSystemOne == 3);
    assert(runCountSystemTwo == 3);

    writeln("################## ECS UNITTEST STOP  ##################");
}


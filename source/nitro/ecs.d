module nitro.ecs;

import std.stdio;
import std.conv;
import std.typetuple;
import std.array;

import nitro.soa;


/****************************************************************
*/
struct Entity { 
	size_t id; 
	int opCmp(ref const Entity entity) const {
        if(this.id < entity.id)
            return -1;
        else if(entity.id < this.id)
            return 1;

        return 0;
	}
}


/****************************************************************
*/
private struct ComponentBits(CS...) { 
private:
	ubyte[CS.length / 8 + 1] _bits;
	
public:	   	   
	void set(CSS...)() { 
		foreach(C; CSS) {
			this._set!C();			
		}
	}				 
	
	void unset(CSS...)() {
		foreach(C; CSS) {
			this._unset!C();			
		}
	}
	
	bool isset(CSS...)() const {
		foreach(C; CSS) {
			if(!this._isset!C()) return false;			
		}
		return true;
	}
	
	void clear() {
		this._bits = this._bits.init;
	}
	
private:	
	void _set(C)() { 
		alias IDX = staticIndexOf!(C, CS);
		static assert(IDX != -1, C.stringof ~ " is not a component of " ~ typeof(this).stringof);
		this._bits[IDX / 8] |=  1 << (IDX % 8);
	}
	
	void _unset(C)() {	   
		alias IDX = staticIndexOf!(C, CS);
		static assert(IDX != -1, C.stringof ~ " is not a component of " ~ typeof(this).stringof);	 
		this._bits[IDX / 8] &= ~(1 << (IDX % 8));
	}
	
	bool _isset(C)() const {		
		alias IDX = staticIndexOf!(C, CS);
		static assert(IDX != -1, C.stringof ~ " is not a component of " ~ typeof(this).stringof);
		return (this._bits[IDX / 8] & (1 << (IDX % 8))) > 0;
	}
}


/****************************************************************
*/
private struct EntityComponentPair(C) {
	Entity[] entities; 
	C[] components;
};


/****************************************************************
*/
private template EntityComponentPairs(CS...) {
	alias EntityComponentPairs = staticMap!(EntityComponentPair, CS);
}


/****************************************************************
*/
class EntityComponentManager(CS...) if(CS.length == 0) {
	void deleteLater(Entity entity) {}
	void deleteLater(PCS...)(Entity entity) {}
	alias clearLater = deleteLater!CS;
	void deleteNow() {}
	Entity createEntity() { assert(0); }
	bool isValid(Entity entity) const { assert(0); }
	bool hasComponents(PCS...)(Entity entity) const { assert(0); }
	void addComponents(PCS...)(Entity entity, PCS pcs) {}
	ref PC getComponent(PC)(Entity entity) { assert(0); }
	QueryResult!(Entity[], CS) query(PCS...)() { assert(0); }
}

/****************************************************************
*/
class EntityComponentManager(CS...) if(CS.length > 0) {
private:
	size_t _nextId = 0;
	ComponentBits!CS[Entity] _mapEntityComponentBits;
	EntityComponentPairs!CS _entityComponentPairs;

	Entity[] _deleteLaterEntities;
	ComponentBits!CS[Entity] _deleteLaterComponents;

public:
	/************************************************************
	*/
	void deleteLater(Entity entity) {
		this._deleteLaterEntities ~= entity;
	}

	/************************************************************
	*/
	void deleteLater(PCS...)(Entity entity) {
		auto p = entity in this._deleteLaterComponents;
		if(p is null) {
			this._deleteLaterComponents[entity] = ComponentBits!CS();
		}
		this._deleteLaterComponents[entity].set!PCS();
	}

	/************************************************************
	*/
	alias clearLater = deleteLater!CS;

	/************************************************************
	*/
	void deleteNow() {
		foreach(e; this._deleteLaterComponents.byKey()) {
			foreach(C; CS) {
				if(this._deleteLaterComponents[e].isset!C()) {
					this._removeComponents!C(e);
				}
			}
		}
		foreach(e; this._deleteLaterEntities) {
			this._destroyEntity(e);
		}
		this._deleteLaterComponents.clear();
		this._deleteLaterEntities.clear();
	}

	/************************************************************
	*/
	Entity createEntity() {
		auto e = Entity(_nextId++);
		_mapEntityComponentBits[e] = ComponentBits!CS();
		return e;
	}
	
	/************************************************************
	*/
	bool isValid(Entity entity) const {
		return (entity in this._mapEntityComponentBits) !is null;
	}

	/************************************************************
	*/
	bool hasComponents(PCS...)(Entity entity) const
	in {
		assert(this.isValid(entity));
	}
	body {
		return this._mapEntityComponentBits[entity].isset!PCS();
	}

	/************************************************************
	*/
	void addComponents(PCS...)(Entity entity, PCS pcs)
	in {
		assert(this.isValid(entity));
		assert(!this.hasComponents!PCS(entity));
	}
	out {
		assert(this.hasComponents!PCS(entity));
	}
	body {
		import std.algorithm : countUntil;
		import std.array : insertInPlace;
		foreach(i, PC; PCS) {		
			alias IDX = staticIndexOf!(PC, CS);
			static assert(IDX != -1, "Component " ~ PC.stringof ~ " not known to ECM");

			auto idx = _entityComponentPairs[IDX].entities.countUntil!(a => a > entity);
			if(idx != -1) {
				_entityComponentPairs[IDX].entities.insertInPlace(idx, entity);
				_entityComponentPairs[IDX].components.insertInPlace(idx, pcs[i]);
			}
			else {
				_entityComponentPairs[IDX].entities ~= entity;
				_entityComponentPairs[IDX].components ~= pcs[i];
			}
		}
		this._mapEntityComponentBits[entity].set!PCS();
	}

	/************************************************************
	*/
	ref PC getComponent(PC)(Entity entity)
	in {
		assert(this.isValid(entity));
		assert(this.hasComponents!PC(entity));
	}
	body {	
		import std.algorithm : countUntil;
		alias IDX = staticIndexOf!(PC, CS);
		auto idx = this._entityComponentPairs[IDX].entities.countUntil(entity);
		if(idx == -1) throw new Exception("entity not found. this should not happen!");
		return this._entityComponentPairs[IDX].components[idx];
	}

	/************************************************************
	*/
	auto query(PCS...)() {
		import std.algorithm : filter, sort;
		auto entities = this._mapEntityComponentBits.byKey.filter!(e => this.hasComponents!PCS(e))().array.sort;
		return QueryResult!(typeof(entities), CS)(entities, this);
	}

private:
	/************************************************************
	*/
	void _destroyEntity(Entity entity) 
	in {
		assert(this.isValid(entity));
	}
	out {
		assert(!this.isValid(entity));
	}
	body {
		this._clearComponents(entity);
		this._mapEntityComponentBits.remove(entity);
	}
	
	/************************************************************
	*/
	void _removeComponents(PCS...)(Entity entity)
	in {
		assert(this.isValid(entity));
	}
	out {
		assert(!this.hasComponents!PCS(entity));
	}
	body {	   
		import std.algorithm : remove, countUntil;
		foreach(c, PC; PCS) {
			alias IDX = staticIndexOf!(PC, CS);
			auto idx = _entityComponentPairs[IDX].entities.countUntil(entity);
			if(idx != -1) {
				_entityComponentPairs[IDX].entities.remove(idx);
				_entityComponentPairs[IDX].components.remove(idx);
			}
		}
		this._mapEntityComponentBits[entity].unset!PCS();
	}
	
	/************************************************************
	*/
	alias _clearComponents = _removeComponents!CS;
}


/****************************************************************
*/
struct QueryResult(R, CS...) {

	size_t[CS.length] indices;
	R _range;
	EntityComponentManager!CS _ecm;

	/************************************************************
	*/
	this(R range, EntityComponentManager!CS ecm){
		this._range = range;
		this._ecm = ecm;
	}
	
	/************************************************************
	*/
	EntityResult!CS front() @property {
		return EntityResult!CS(_range.front, &indices, _ecm);
	}
	
	/************************************************************
	*/
	void popFront() {
		this._range.popFront();
	}
	
	/************************************************************
	*/
	bool empty() const @property {
		return this._range.empty;
	}
}


/****************************************************************
*/
struct EntityResult(CS...) if(CS.length == 0) {
    Entity _e = Entity(0);
    alias _e this;
    this(Entity e, size_t[CS.length]* pIndices, EntityComponentManager!CS ecm){}
    ref PCS getComponent(PCS)() { assert(0); }
    bool hasComponent(PCS...)() { assert(0); }

}

/****************************************************************
*/
struct EntityResult(CS...) if(CS.length > 0) {
public:
	Entity _e;
	alias _e this;

private:
	size_t[CS.length]* _pIndices;
	EntityComponentManager!CS _ecm;

	/************************************************************
	*/
	this(Entity e, size_t[CS.length]* pIndices, EntityComponentManager!CS ecm) {
		this._e = e;
		this._pIndices = pIndices;
		this._ecm = ecm;
	}
		
	/************************************************************
	if there is no such component for this entity an exception is thrown
	*/
	ref PCS getComponent(PCS)() {
		enum IDX = staticIndexOf!(PCS, CS);
		for(;(*this._pIndices)[IDX] < _ecm._entityComponentPairs[IDX].entities.length; ++((*this._pIndices)[IDX])) {
			if(_ecm._entityComponentPairs[IDX].entities[(*this._pIndices)[IDX]] == this._e) {
				return _ecm._entityComponentPairs[IDX].components[(*this._pIndices)[IDX]];
			}
		}
		throw new Exception("no such component for entity");
	}

	/************************************************************
	*/
	bool hasComponent(PCS...)() {
		return _ecm.hasComponents!PCS(_e);
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
	auto system(alias S)() {		
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

            ecm.deleteNow();
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

                Entity en = e;
                if(e.hasComponent!ComponentOne()) {
                    assert(!e.hasComponent!ComponentTwo());
                    auto component = e.getComponent!ComponentOne();
                    if(runCountSystemOne == 2) { assert(en.id == 5 && component.FieldOne == 10 && component.FieldTwo == "a" && component.FieldThree == true); }
                }
                if(e.hasComponent!ComponentTwo()) {
                    assert(!e.hasComponent!ComponentOne());
                    auto component = e.getComponent!ComponentTwo();
                    if(runCountSystemOne == 2) { assert(en.id == 6 && component.FieldOne == 11 && component.FieldTwo == "b" && component.FieldThree == false); }
                }
                ecm.clearLater(e);
            }

            if(runCountSystemOne == 2) { 
                assert(countComponentThreeFound == 2); 
            }
            else {
                assert(countComponentThreeFound == 0); 
            }


            ecm.deleteNow();
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

    }
}

unittest {
	import std.typetuple : TypeTuple;
    import std.stdio : writeln; 
    writeln("################## ECS UNITTEST START ##################");

	alias TEST_SYSTEMS = TypeTuple!(SystemOne, SystemTwo);
	alias TEST_COMPONENTS = TypeTuple!(ComponentOne, ComponentTwo, ComponentThree);

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

    assert(test_ecm.isValid(entity_one));
    assert(test_ecm.isValid(entity_two));
    assert(test_ecm.isValid(entity_three));

	test_ecm.deleteLater(entity_three);
	test_ecm.deleteNow();

    assert(test_ecm.isValid(entity_one));
    assert(test_ecm.isValid(entity_two));
    assert(!test_ecm.isValid(entity_three));

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.addComponents(entity_one, ComponentOne(1, "hi", true));

	assert(test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one)); 
	assert(!test_ecm.hasComponents!ComponentOne(entity_two)); 
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two)); 

	assert(!test_ecm.hasComponents!(ComponentOne,ComponentTwo)(entity_one));

	test_ecm.deleteLater!ComponentOne(entity_one);
	test_ecm.deleteNow();

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
    assert(component_one.FieldOne == 1 && component_one.FieldTwo == "hi" && component_one.FieldThree == true);

	Entity entity_four = test_ecm.createEntity();
	test_ecm.addComponents(entity_four, ComponentOne(6, "is", false));
	test_ecm.addComponents(entity_four, ComponentTwo(6, "my", true));
    test_ecm.deleteLater(entity_four);

	Entity lastEntity = Entity(size_t.max);
    int currentIteration = 1;
	foreach(e; test_ecm.query!(ComponentOne, ComponentTwo)()) {
        assert(currentIteration <= 3);

		assert(e.hasComponent!ComponentOne());
		assert(e.hasComponent!ComponentTwo());

		auto component = e.getComponent!ComponentOne();
		Entity en = cast(Entity)e;
        if(currentIteration == 1) { assert(en.id == 0 && component.FieldOne == 1 && component.FieldTwo == "hi" && component.FieldThree == true); }
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
	test_ecm.deleteNow();

    int currentIterationTwo = 1;
	foreach(e; test_ecm.query!ComponentOne()) {
        assert(currentIterationTwo <= 2);

		assert(e.hasComponent!ComponentOne()); 
		assert(!e.hasComponent!ComponentTwo());

		auto component = e.getComponent!ComponentOne();
		Entity en = e;
        if(currentIterationTwo == 1) { assert(en.id == 0 && component.FieldOne == 1 && component.FieldTwo == "hi" && component.FieldThree == true); }
        if(currentIterationTwo == 2) { assert(en.id == 1 && component.FieldOne == 3 && component.FieldTwo == "lets" && component.FieldThree == true); }
        currentIterationTwo++;
	}

    int currentIterationThree = 1;
	foreach(e; test_ecm.query!ComponentTwo()) {
        assert(currentIterationThree <= 1);
		assert(!e.hasComponent!ComponentOne());
		assert(e.hasComponent!ComponentTwo());

		auto component = e.getComponent!ComponentTwo();
		Entity en = e;
        if(currentIterationThree == 1) { assert(en.id == 1 && component.FieldOne == 3 && component.FieldTwo == "lets" && component.FieldThree == true); }
        currentIterationThree++;
	}

	assert(test_ecm.hasComponents!ComponentOne(entity_one)) ;
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(test_ecm.hasComponents!ComponentTwo(entity_two)) ;

	assert(test_ecm.isValid(entity_one));
	assert(test_ecm.isValid(entity_two));

	test_ecm.deleteLater!ComponentOne(entity_one);
	test_ecm.deleteLater!ComponentTwo(entity_two);
	test_ecm.deleteNow();

	assert(!test_ecm.hasComponents!ComponentOne(entity_one));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_one));
	assert(!test_ecm.hasComponents!ComponentOne(entity_two));
	assert(!test_ecm.hasComponents!ComponentTwo(entity_two));

	test_ecm.deleteLater(entity_one);
	test_ecm.deleteLater(entity_two);
	test_ecm.deleteNow();

	assert(!test_ecm.isValid(entity_one));
	assert(!test_ecm.isValid(entity_two));

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


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
	Entity createEntity() {return Entity(0);}
	bool isValid(Entity entity) const {return false;}
	bool hasComponents(PCS...)(Entity entity) const {return false;}
	void addComponents(PCS...)(Entity entity, PCS pcs) {}
	auto ref getComponent(PC)(Entity entity) {return PC();}
	auto query(PCS...)() {return QueryResult!(Entity[], CS)([], this);} 
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
	auto ref getComponent(PC)(Entity entity)
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
    auto ref getComponent(PCS)() { return PCS(); }
    bool hasComponent(PCS...)() { return false; }

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
	auto ref getComponent(PCS)() {
		enum IDX = staticIndexOf!(PCS, CS);
		for(;(*this._pIndices)[IDX] < _ecm._entityComponentPairs[IDX].entities.length; ++((*this._pIndices)[IDX])) {
			if(_ecm._entityComponentPairs[IDX].entities[(*this._pIndices)[IDX]] == this._e) {
				return (_ecm._entityComponentPairs[IDX].components[(*this._pIndices)[IDX]]);
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


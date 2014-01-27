// Written in the D programming language.
/**						   
Copyright: Copyright Felix 'Zoadian' Hufnagel 2014-.

License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors:   $(WEB zoadian.de, Felix 'Zoadian' Hufnagel)
*/
module nitro.ecm;

import std.typetuple : NoDuplicates, staticMap, staticIndexOf;
import std.algorithm : filter;
import std.typecons : Typedef;


struct Entity { 
	ulong id; 
	alias id this; 
}
	
class EntityComponentManager(ALL_COMPONENTS...) if(ALL_COMPONENTS.length == 0) {
	Entity createEntity(){return Entity(0);}
	void destroyEntity(Entity entity){}
	bool isValid(Entity entity){return false;}
	void addComponent(PCS...)(Entity entity, PCS pcs){}
	bool hasComponent(PCS...)(Entity entity){return false;}
	PC getComponent(PC)(Entity entity){return PC();}
	void removeComponent(PCS...)(Entity entity){}
	void clearComponents(Entity entity){}
	Entity[] query(PCS...)(){return [Entity(0)];}
}

/**
EntityComponentManager
*/
class EntityComponentManager(ALL_COMPONENTS...) if(ALL_COMPONENTS.length > 0) {
private:			
	alias CS = NoDuplicates!ALL_COMPONENTS;		
	alias _MapType(T) = T[Entity];
	alias E_CS_MAP = staticMap!(_MapType, CS);
	Entity _cnt = Entity(0);			  
	ComponentMask!CS[Entity] _componentMasks;
	E_CS_MAP _components;

	//pragma(msg, "========================");
	//pragma(msg, "Components: ", CS);
	//pragma(msg, "========================");

public:
	/**
	Creates an Entity.
	*/
	Entity createEntity() {
		Entity entity = Entity(++_cnt.id);		   
		this._componentMasks[entity] = ComponentMask!CS();
		//this._componentMasks.rehash();
		return entity;
	}

	/**
	Destroys an Entity and Removes all its Components.
	*/
	void destroyEntity(Entity entity) {
		this._componentMasks.remove(entity); 
		//this._componentMasks.rehash();
		foreach(c, C; CS) {					  
			this._components[c].remove(entity);
		}
	}

	/**
	Check if an Entity is still valid (== not destroyed).
	*/
	bool isValid(Entity entity) {
		return (entity in this._componentMasks) !is null;
	}

	/**
	Adds Components to an Entity.
	*/
	void addComponent(PCS...)(Entity entity, PCS pcs) {	  
		this.getMask(entity).set!PCS();	     
		foreach(c, C; PCS) {					
			alias IDX = staticIndexOf!(C, CS);
			this._components[IDX][entity] = pcs[c];
		}
	}

	/**
	Check if an Entity has given set of Components.
	*/
	bool hasComponent(PCS...)(Entity entity) {
		return this.getMask(entity).isset!PCS();
	}

	/**
	Get an Component from given Entity. If it does not exist, returns null.
	*/
	auto getComponent(PC)(Entity entity) {	   
		alias IDX = staticIndexOf!(PC, CS);
		static assert(IDX != -1, PC ~": no such component");
		assert(this.hasComponent!PC(entity));//optional!
		return entity in this._components[IDX];
	} 

	/**
	Removes given set of Components from an Entity.
	*/
	void removeComponent(PCS...)(Entity entity) {	   
		this.getMask(entity).unset!PCS();
		foreach(c, C; PCS) {	
			alias IDX = staticIndexOf!(C, CS);
			this._components[IDX].remove(entity);
		}
	}

	/**
	Removes all Components from an Entity.
	*/
	void clearComponents(Entity entity) {	   
		this.getMask(entity).clear();
		foreach(c, C; CS) {					  
			this._components[c].remove(entity);
		}
	}

	/**
	Returns an InputRange that iterates over all Entities with given set of Components.
	*/									   
	auto query(PCS...)() {
		return this._componentMasks.byKey.filter!( entity => hasComponent!PCS(entity) )();
	}

private:
	auto getMask(Entity entity) {	  
		assert(this.isValid(entity));
		return entity in this._componentMasks;
	}
}


private struct ComponentMask(CS...) { 
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

	bool isset(CSS...)() {
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

	bool _isset(C)() {		
		alias IDX = staticIndexOf!(C, CS);
		static assert(IDX != -1, C.stringof ~ " is not a component of " ~ typeof(this).stringof);
		return (this._bits[IDX / 8] & (1 << (IDX % 8))) > 0;
	}
}	 

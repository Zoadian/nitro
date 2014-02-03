# nitro

An Entity Component System (ECS) for the D Programming Language.

## Intro

Nitro implements a basic ECS architecture. Additional information is broadly available but often differs with implementation. Some sources are: [T-machine](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/), [Wikipedia](http://en.wikipedia.org/wiki/Entity_component_system) and [RichardLords](http://www.richardlord.net/blog/what-is-an-entity-framework). The following description may be specific to this implementation.

### Basic terminology

* Entities are unique identifiers (size_t). Components can be attached and removed at runtime.
* Components are datasets(structs) that can be attached to entities and represent a single aspect of something (for example the health of a player).
* A query returns a forward range to iterate over all entites with specified components (for example a query for all entities with player name and health) 
* Systems encapsulate the execution logic that handles a specific aspect of the program (single purpose).

### Main characteristics

* Relationships are composed through data, similiar to relational databases
* Composition is accomplished by attatching components to entities
* Data is retrieved by querying for specific component combinations (similiar to tagging)
* Execution code is separated from data and can be replaced with ease (loose coupling)
* Execution flow is defined by an ordered list of systems that each handle different aspects of the program.

## Usage

nitro is a combination of of the concepts of entities, components and systems. Systems encapsulate the execution logic and while they are intended to define the flow of the program, they are optional. In addition to these basic components nitro.gen contains helpers that aim to automate specific parts of the implementation.

### Entities/Components

TODO:
* EntityComponentManager
	* createEntity
	* destroyEntity
	* isValid
	* addComponent
	* hasComponent
	* getComponent
	* removeComponent
	* clearComponents
	* query

### Systems

TODO:
* SystemManager
    * Constructors
    * run
    * system

### nitro.gen

TODO:
	* AutoQuery
    * AutoQueryMapper
    * pushEntity

    * MakeECS
        * SystemsOfModule
        * ComponentsOfModule

## License

All parts of nitro are released under the [Boost software license - version 1.0](https://github.com/Zoadian/nitro/blob/master/LICENSE.txt)
 
## Todo

* Deletion stack for entities and components
* Usage of SoA implementation
* Unittests
* Add implementation notes to readme
* Release of first major release (1.0.0)






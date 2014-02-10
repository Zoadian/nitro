# nitro

An Entity Component System (ECS) for the D Programming Language.

## Intro

Nitro implements a basic ECS architecture. Additional information is broadly available but often differs with implementation. Some sources are: [T-machine](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/), [Wikipedia](http://en.wikipedia.org/wiki/Entity_component_system) and [RichardLords blog](http://www.richardlord.net/blog/what-is-an-entity-framework). The following description may be specific to this implementation.

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

ECS is a combination of of the concepts of entities, components and systems. Systems encapsulate the execution logic and while they are intended to define the flow of the program, in nitro they are optional. In addition to these basic components nitro.gen contains helpers that aim to automate specific parts of the implementation.

### Entities/Components

To work with entities and components you first have to create an instance of EntityComponentManager with all component types you want to use as template parameters. For example:

    auto myECM = new EntityComponentManager!(MyComponent)();
    
A component can be any struct consisting of fields, for example:

    struct MyComponent {
        int id;
        string msg;
    }

To see how to automatically generate 
The EntityComponentManager type can also be automatically generated, see nitro.gen.

Nitro works with the combination of entities and components, where components contain data and can be attatched to entities which are represented by an unique id. 

TODO:
    * deleteLater (entities/components)
    * clearLater 
    * deleteNow
    * createEntity
    * isValid
    * hasComponents
    * addComponents
    * getComponent
    * query

### Systems

TODO:
* SystemManager
    * ...constructors
    * run
    * system

### nitro.gen

#### 

TODO:
* ecsgen
    * MakeECS
    * SystemsOfModule
    * ComponentsOfModule
* querygen
    * AutoQuery
    * AutoQueryMapper
    * pushEntity
    * ...query functions

## Implementation Notes

Nitro stores everything as a Structure of Arrays (SoA). 

### Internal Component Representation

For each Component Nitro generates a flat structure of arrays.<br />
Let's assume we have:

    struct Point {int x,y,z; }
    @Component struct TestComp { int a; Point b; }

Nitro will store it internally as:

    int[] //a
    int[] //b.x
    int[] //b.y
    int[] //b.z

### Accessing Components

getComponent!TestComp() returns an Accessor!TestComp that mimics all fields of the original TestComp.<br />
Why?<br />
Let's say we only access TestComp.a but have lots of TestComp components we want to iterate. Normally we'd pull all fields of TestComp into our CPU cache. By using Accessor!TestComp only TestComp.a is pulled in.

## License

All parts of nitro are released under the [Boost software license - version 1.0](https://github.com/Zoadian/nitro/blob/master/LICENSE.txt)
 
## Todo

* Finish readme
* Support empty components
* Add implementation notes to readme
* Code cleanup
* Release of first major release (1.0.0)

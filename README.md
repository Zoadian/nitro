# nitro

An Entity Component System (ECS) for the D Programming Language.

* Relationships are composed through data, similiar to relational databases.
* Composition is accomplished by attatching Components to Entities.
* Data is retrieved by querying for specific component combinations.
* Program logic is separated from data and can be replaced with ease (loose coupling).

Additional information on Entity Component Systems is broadly available but often differs in implementation. <br />
See also:
[T-machine](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/),
[Wikipedia](http://en.wikipedia.org/wiki/Entity_component_system) and 
[RichardLords blog](http://www.richardlord.net/blog/what-is-an-entity-framework).

## Terminology

#### Entitiy
Entities are just unique identifiers. Components can be attached or detached at runtime.<br />
`Entity e;`

#### Component
Components are just data (structs without functions). They allow simple composition of objects, while avoiding class inheritance and virtual function performance penalties altogether.<br />
`@Component struct PlayerComponent { string name; int x; int y; int z; } `<br />
`@Component struct MovementComponent { int x; int y; } `

#### System
Systems encapsulate the logic of specific aspects of the program. They are modular and can easily be extended, removed or replaced.<br /> 
`@System class GravitySystem(ECM) { void run(ECM ecm) { /*...*/ } }`<br />
`@System class MovementSystem(ECM) { void run(ECM ecm) { /*...*/ } }`

#### EntityComponentManager
...<br />
`auto ecm = new EntityComponentManager!(PlayerComponent, WeaponComponent)();`

#### SystemManager
...<br />
`alias ECM = EntityComponentManager!(PlayerComponent, WeaponComponent);`<br />
`auto sm = new SystemManager!(ECM, GravitySystem, MovementSystem)();`

#### Query
Queries result in a QueryResults (forward ranges) containing all Entities with the requested Components.<br />
`auto result = ecs.query!(PlayerComponent, WeaponComponent);`



## Example 

    @Component struct PlayerComponent {
        string name; 
        int x; 
        int y; 
        int z;
    } 
    
    @Component struct MovementComponent {
        int x; 
        int y; 
    }
    
    @System class GravitySystem(ECM) { 
        void run(ECM ecm) { 
            foreach(entity; ecm.query!PlayerComponent()) {
                auto playerComponent = entity.getComponent!PlayerComponent();
                playerComponent.z -= 1;
            }
        } 
    }
    
    @System class MovementSystem(ECM) { 
        void run(ECM ecm) { 
            foreach(entity; ecm.query!(PlayerComponent, MovementComponent)()) {
                auto playerComponent = entity.getComponent!PlayerComponent();
                auto movementComponent = entity.getComponent!MovementComponent();
                playerComponent.x += movementComponent.x;
                playerComponent.y += movementComponent.y;
            }
        } 
    }
    
    alias ECM = EntityComponentManager!(PlayerComponent, WeaponComponent);
    auto sm = new SystemManager!(ECM, GravitySystem, MovementSystem)();
    
    for(;;) {
        sm.run();
    }


## License

All parts of nitro are released under the [Boost software license - version 1.0](https://github.com/Zoadian/nitro/blob/master/LICENSE.txt)





# ===============================
# ===============================
# ===============================
# ===============================
# ===============================

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

 
## Todo

* Finish readme
* Think about "delay addComponent/removeComponent"
* threadsafe
* Release of first major release (1.0.0)

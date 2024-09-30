# EventStore

A package for using event-sourcing in applications. It is particularly useful when using the CQRS architecture style. The Command side would employ the `Source` target, and the Query side would use the `Projection` target.

State is stored in a relational database with built-in support for SQLite and PostgreSQL.

EventStore needs to run on a backend server. This package does not include a web server but you can try using [Vapor](https://vapor.codes) or [Webber](https://github.com/swifweb/webber).

# The Concept Behind Event Sourcing

By focusing on how the state *changes*, we can better understand how our domain works.

The idea of event sourcing is to not simply store the current *state* of the application, but instead store each historical *change* to the state. We call such changes ‘events.’

There are some benefits to using this idea; the most obvious ones are perhaps immutability and auditing. When an event has been recorded, that historical information will itself never change. It makes referring to the data much simpler, and you need never worry about concurrent updates. Every event also records a timestamp and a username which can be very useful metadata for auditing.

Event sourcing also allows creating independent *projections* of the state. You can replay all the changes at any time, and maintain a different storage location with an alternate view into the data. For example you can gather all the current state for easy indexing and quick access. You can ignore a lot of the information, and focus on generating the data structure that makes your particular use case simple and performant.

Event Sourcing is a product of Domain-Driven Design (DDD). In DDD, we have two carriers of state: the value object and the entity.

## Value Objects

Value objects are not modeled by this library, but it is still important to understand them.

A value object is (as the term implies) an object that represents a specific value. Values never change; you can only replace a value with a new one. Value objects are therefore always immutable.

Value objects typically have two functions: they can be compared for structural equality, and they can be validated for correct user input.

It should not be possible to instantiate an invalid value object. The initializer should prevent such, typically by throwing an exception or returning `nil` when invalid data is encountered. If the programmer can rely on this working, they will not need to validate the data in their code; it is enough to declare that a variable must be of the correct type (and not `nil`).

Most value objects conform to `Equatable` and `Hashable`. They can thus be used in sets and as dictionary keys. A mutable object used as a dictionary key can be changed after it's added making it impossible to find again. Immutability is necessary to guarantee correct behaviour.

`Equatable` value objects can also be `Comparable` and they can be used in calculations. You might for example add (`+`) two value objects of same type to get their sum. Or you might multiply a value object with a scalar (e.g. an interest rate). The result of a calculation is typically an object of the same type as the input, but it could be otherwise. E.g. `Ingredient1` plus `Ingredient2` might return a `Cake`.

Value objects should also be encapsulated. They should have an internal representation of data and an external interface. Users of the value object should only ever couple to the interface, never to the concrete data representation. That allows the storage strategy to change without breaking references to the value object. And it also helps the programmer stay focussed on the *meaning* of the value rather than its *composition*.

Should, for example, the data representation of an amount of `Money` be composed of an `Int` counting the cents (100 meaning one dollar), a `Double` value of dollars (0.5 to represent 50 cents) or two separate `Int` values (one for dollars and one for cents, where cents < 100)? If you ever need to change the data format to support new use cases or a need for higher precision, encapsulation is a guard against errors in all code outside the `Money` type itself.

## Entities

Not everything can be made immutable. If it were, we would have little (if any) use of software. We need to gather new data, and update existing data. We need to support business processes and user tasks, both of which rely heavily on *changing* the data stored in the system. Without data changes, the usefulness of the system would be very limited.

But rather than manipulating *data*, in its specific format and structure, Domain-Driven Design (DDD) teaches us to focus on what that data *means* conceptually and/or metaphorically. And why and how it changes. The formatting and structure of the data can be altered in many ways and still represent the same meaning; the same state.

DDD separates the state of the system into parts called entities; the state of the system is the aggregated state of all entities. Each `Entity` defines invariants that must be maintained. Like value objects, entities should be encapsulated. The interface of an `Entity` should only expose meaningful operations, not direct state/data manipulation. If an action executes an operation that is invalid/unsupported for its current state, the `Entity` should throw an exception.

Unlike value objects, entities possess an identifier. Since the `Entity` is stateful, there must be a way to identify which entity to modify. To summarise there are three main differences between value objects and entities:

1. Value objects are immutable, while entities are stateful.
2. A value object has meaning, while an entity has an identity.
    - Comparisons between value objects look at their entire structure,
      while comparisons between entities only concern their ids.
3. Value objects are often and easily discarded and recreated, while entities live on for a long time.

## Events

By focusing on how the state *changes*, we can better understand how our domain works.

This library employs event sourcing, which means that we define the state of an entity by listing the changes that has happened to it since it was first added to the system/application. These changes are commonly referred to as *events*. The state of the entity hasn't officially changed until the events are published. When they have been published, they are forever a part of the entity's history. They are never changed or removed. The history up to that point will never change. Any new events will always be appended to the end of the history.

# Technical Notes

The point of DDD is to *not* focus on the technology or other implementation details. However, the technical choices do need to be mentioned, because developers believe they need to know them. If they actually do or not is beside the point.

## Optimistic locking

Concurrent modification of shared state can be a big problem. If two users happen to change the same entity at the same time, there's a risk that they both read the same initial state, and then make conflicting changes that cannot be reconciled. This library employs “optimistic locking” to avoid such a scenario. Every entity has a `version` that is read when it is reconstituted, and again before publishing changes. Only if the version is the same at both instants is publishing allowed.

If the stored state is the same, it is assumed that no other process has changed the state in the intervening time. If no one has yet published new changes, there is no possibility of a conflict, and publishing the current changes will be allowed. At that time, the version is also incremented to indicate to any other active process that the state has now changed.

If the stored version number is different from what was read at reconstitution, the state has changed during the execution of this action. Since a different state can potentially affect the outcome of this action, all the current changes are to be considered invalid and publishing them is not allowed. Our only choices are to either abort the operation entirely or perform the action again. If we choose to repeat the action, we must discard the current, invalid state information, and reconstitute the entity from its new state. Then we can perform the action on this state, and try to publish those changes.

## Tables

State is stored in a relational database with built-in support for SQLite and PostgreSQL. Note that table names are never quoted in the SQL scripts, and, because reasons, PostgreSQL converts unquoted names to lowercase. That is however the only difference you will see.

The `Entities` table:

```sql
"id" TEXT PRIMARY KEY
"type" TEXT
"version" INT
```

The `Entities` table has two data columns: the `type` and the `version` of an entity. The version is used for concurrency checks (see Optimistic Concurrency above). The type is used as a runtime type-checker. When reconstituting the state of an entity it needs to be the type you expect. If it isn't, an error will be thrown.

The `Events` table:

```sql
"entity_id" TEXT
"entity_type" TEXT
"name" TEXT
"details" TEXT
"actor" TEXT
"timestamp" DECIMAL(12,7) -- Julian Day (days since ) representation
"version" INT
"position" BIGINT
```

The events table is the main storage space for entity state. The `entity_id` and `entity_type` columns must match the corresponding columns for a row in the `Entities` table. This is the entity that changed with this event.

The `name` and `details` (JSON) columns define what changed for the entity. The `version` column orders events per entity, and the last event stored for an entity must match its `version` column. The `position` column orders events globally and is motly used for projections.

The `actor` and `timestamp` columns are metadata that can be used for auditing.

The `timestamp` is stored as the number of days (including fraction) that have passed since midnight UTC on Jan 1, 1970 (a.k.a. the Unix Epoch).

## Database Support

There is currently only support for two database providers.

- PostgreSQL
- SQLite

### What about SQL Server?

As of 2022, there is no known SQL Server driver available for Swift. Here's a discussion that indicates some small progress: [https://forums.swift.org/t/sql-server-driver/20327](https://forums.swift.org/t/sql-server-driver/20327). It is unknown what has happened since April 2020.

Apparently SQL Server is not prioritised by the Swift community.

### Maybe add suppoet for MySQL?

MySQL support does not feel as important as SQL Server. On the other hand, MySQL has Swift drivers. Here are a couple:

- [https://github.com/mcorega/MySqlSwiftNative](https://github.com/mcorega/MySqlSwiftNative)
- [https://github.com/novi/mysql-swift](https://github.com/novi/mysql-swift)

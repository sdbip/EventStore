# EventStore

A package for using event-sourcing in applications. It is particularly useful when using the CQRS architecture style. The Command side would employ the `Source` target, and the Query side would use the `Projection` target.

State is stored in a relational database with built-in support for SQLite and PostgreSQL.

EventStore needs to run on a backend server. This package does not include a web server but you can try using [Vapor](https://vapor.codes) or [Webber](https://github.com/swifweb/webber).

# The Concept Behind Event Sourcing

The idea of event sourcing is to not simply store the current *state* of the application, but instead store each historical *change* to the state. We call such changes *events*.

There are some benefits to using this idea; the most obvious ones are perhaps immutability and auditing. When an event has been recorded, that information will itself never change. It makes referring to the data much simpler, and you need never worry about concurrent updates. Every event also records a timestamp and a username. This can be very useful metadata for auditing and where to invest in more education.

Event sourcing also allows creating independent *projections* of the state. You can replay all the changes at any time, and maintain a different storage location with an alternate view into the data. For example you can gather all the current state for easy indexing and quick access. You can ignore a lot of the information, and focus on generating the data structure that makes your particular use case simple and performant.

Event Sourcing is a product of Domain-Driven Design (DDD). In DDD, we have two carriers of state: the value object and the entity.

## Value Objects

Value objects in general are not modeled here, but it is still important to understand them. A value object is (as the term implies) an object that represents a specific value. Values cannot be modified, only replaced. Value objects are therefore always immutable (except maybe in Swift).

In Swift, value objects can be defined through value-semantics (`struct`). Thanks to copy-on-write, Swift has much less need for immutability. In rare cases, you might decide that it is okay to make value objects mutable. You should still be very restricted with *how* the objects may be changed, though.

Value objects are also encapsulated. They have an internal representation of data and an external interface. Users of the value object may only couple to the interface, not to the data representation.

## Entities

Not everything can be made immutable. If it were, we would have little (if any) use of software. We need to gather new data, and update existing data. We need to support business processes and user tasks, both of which heavily rely on *changing* the data stored in the system. Domain-driven design (DDD) was formulated in part to focus on these processes, rather than the data they manipulate.

In DDD we do not focus on the data as such, but on what the data *represents*. An *entity* is an object that has state. State is information (data) about the current reality of a particular thing. That “thing” is the entity. It might be a physical “thing” (eg. a person, a vehicle, a device, etc) or it might be non-physical (like a project, a document, a department of our company...).

## Events

By focusing on how the state *changes*, we can better understand how our domain works.

This library employs event sourcing, which means that we define the state of an entity by listing the changes that has happened to it since it was first added to the system/application. These changes are commonly referred to as *events*. The state of the entity hasn't officially changed until the events are published. When they have been published, they are forever a part of the entity's history. They are never changed or removed. The history up to that point will never change. Any new events will always be appended to the end of the history.

An action that changes the state of an entity (typically) needs to first reconstitute the entity from its already published events. This is done by repeatedly calling the `apply(:)` method with the events in the order they were added. When this method is called, your entity should remember the information it needs in order to determine how its current state affects the result of the action (and any other supported action).

When the action performs the actual change, the entity should add events to its `unpublishedEvents` property. These events (appended to the sequence of already published events) define its new state. This state is not official until the new events have been published.

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

As of 2022, there is no known SQL Server driver available for Swift. Here's a discussion that indicates some small progress: https://forums.swift.org/t/sql-server-driver/20327. It is unknown what has happened since April 2020.

Apparently SQL Server is not prioritised by the Swift community.

### Maybe add suppoet for MySQL?

MySQL support does not feel as important as SQL Server. On the other hand, MySQL has Swift drivers. Here are a couple:

- https://github.com/mcorega/MySqlSwiftNative
- https://github.com/novi/mysql-swift


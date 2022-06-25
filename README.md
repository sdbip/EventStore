# EventStore

A package for using event-sourcing in applications. It is particularly useful when using the CQRS architecture style. State is stored in a relational database with built-in support for SQLite and PostgreSQL.

# The Concept Behind Event Sourcing

The idea of event sourcing is to not simply store the current *state* of the application, but instead store each historical *change* to the state. We call such changes *events*.

There are some benefits to using this idea; the most obvious ones are perhaps immutability and auditing. When an event has been recorded, that information will itself never change. It makes referring to the data much simpler, and you need never worry about concurrent updates. Every event also records a timestamp and a username. This can be very useful metadata for auditing and where to invest in more education.

Event sourcing also allows creating independent *projections* of the state. You can replay all the changes at any time, and maintain a different storage location with an alternate view into the data. For example you can gather all the current state for easy indexing and quick access. You can ignore a lot of the information, and focus on generating the data structure that makes your particular use case simple and performant.

Event Sourcing is a product of Domain-Driven Design (DDD). In DDD, we have two carriers of state: the value object and the entity.

## Value Objects

Value objects in general are not modelled here, but it is still important to understand them. A value object is (as the term implies) an object that represents a specific value. A value is an unchanging concept; eg. five dollars is always five dollars. Therefore, value objects are immutable. If I give you an object that represents five dollars, that object must never change to four dollars.

A value object may be *assigned* to a property of another object, and that *property* may change. Changing the property, however, must not be done by modifying the value object; it must be done by assigning a different object. This rule prevents a range of bugs. A typical example of a bug is if you are running a computation in the background, and the objects you are using for that calculation suddenly change. The result of the computation will be incorrect. If that computation involves updating an object, that object will have an incorrect state. Immutability is an important principle. Wherever you can use it: use it!

Most languages have mechanisms for specifying values that cannot change. In Swift, we use the `let` keyword. A `Money` value object might look like this:

```swift
public struct Money {
    public let currency: Currency
    private let cents: Int

    public amount: Double {
        return cents / 100.0
    }

    public init(_ amount: Double, currency: Currency) {
        self.cents = Int(amount * 100)
        self.currency = currency
    }
}

extension Money: CustomStringConvertible {
    var description: String {
        return currency.isPrefixed
            ? "\(currency) \(amount)"
            : "\(amount) \(currency)"
    }
}
```

## Entities

Not everything can be made immutable. If it were, we would have little (if any) use of software. We need to gather new data, and update existing data. We need to support business processes and user tasks, both of which heavily rely on *changing* the data stored in the system. Domain-driven design (DDD) was formulated in part to focus on these processes, rather than the data they manipulate.

In DDD we do not focus on the data as such, but on what the data *represents*. An *entity* is an object that has state. State is information (data) about the current reality of a particular thing. That “thing” is the entity. It might be a physical “thing” (eg. a person, a vehicle, a device, etc) or it might be non-physical (like a project, a document, a department of our company...).

## Events

By focusing on how the state *changes*, we can better understand how our domain works.

This library employs event sourcing, which means that we define the state of an entity by listing the changes that has happened to it since it was first added to the system/application. These changes are commonly referred to as *events*. The state of the entity hasn't officially changed until the events are published. When they have been published, they are forever a part of the entity's history. They are never changed or removed. The history up to that point will never change. Any new events will always be appended to the end of the history.

An action that changes the state of an entity (typically) needs to first reconstitute the entity from its already published events. This is done by repeatedly calling the `apply(:)` method with the events in the order they were added. When this method is called, your entity should remember the information it needs in order to determine how its current state affects the result of the action (and any other supported action).

When the action performs the actual change, the entity should add events to its `unpublishedEvents` property. These events (appended to the sequence of already published events) define its new state. This state is not official until the new events have been published.

# Projections

# Technical Notes

The point of DDD is to *not* focus on the technology or other implementation details. However, the technical choices do need to be mentioned, because developers believe they need to know them. If they actually do or not is beside the point.

## Optimistic locking

Concurrent modification of shared state can be a big problem. If two users happen to change the same entity at the same time, there's a risk that they both read the same initial state, and then make conflicting changes that cannot be reconciled. This library employs “optimistic locking” to avoid such a scenario. Every entity has a `version` that is read when it is reconstituted, and again before publishing changes. Only if the version is the same at both instants is publishing allowed.

If the stored state is the same, it is assumed that no other process has changed the state in the intervening time. If no one has yet published new changes, there is no possibility of a conflict, and publishing the current changes will be allowed. At that time, the version is also incremented to indicate to any other active process that the state has now changed.

If the stored version number is different from what was read at reconstitution, the state has changed during the execution of this action. Since a different state can potentially affect the outcome of this action, all the current changes are to be considered invalid and publishing them is not allowed. Our only choices are to either abort the operation entirely or perform the action again. If we choose to repeat the action, we must discard the current, invalid state information, and reconstitute the entity from its new state. Then we can perform the action on this state, and try to publish those changes.

## Tables

The `Entities` table:

```sql
"id" TEXT PRIMARY KEY
"type" TEXT
"version" INT
```

The `Entities` table has two data columns: the `type` and the `version` of an entity. The version is used for concurrency checks (see Optimistic Concurrency above). The type is used as a runtime type-checker. When reconstituting the state of an entity it needs to be the type you expect. If it isn't, an error will be thrown.

The `Events` table:

```sql
"entityId" TEXT
"entityType" TEXT
"name" TEXT
"details" TEXT
"actor" TEXT
"timestamp" DECIMAL(14,7) -- Julian Day (days since ) representation
"version" INT
"position" BIGINT
```

The events table is the main storage space for entity state. The `entityId` and `entityType` columns must match the corresponding columns for a row in the `Entities` table. This is the entity that changed with this event.

The `name` and `details` (JSON) columns define what changed for the entity. The `version` column orders events per entity, and the last event stored for an entity must match its `version` column. The `position` column orders events globally and is motly used for projections.

The `actor` and `timestamp` columns are metadata that can be used for auditing.

The `Properties` table:

```sql
name TEXT PRIMARY KEY
value DATA
```

The properties table is at the moment only used to store the position for the next event. You could use this to add other information as needed.

## Julian Day

The event timestamp is stored in the Julian day format.

> The Julian day number (JDN) is the integer assigned to a whole solar day in the Julian day count starting from noon Universal Time, with Julian day number 0 assigned to the day starting at noon on [November 24, 4714 BC].
> -- [Wikipedia](https://en.wikipedia.org/wiki/Julian_day)

You can convert calendar dates to/from a Julian day using this tool: https://www.typecalendar.com/julian-date.

# The Concept of Event Sourcing

This document is meant to help understand DDD and event sourcing. There is separate documentation describing [usage](./USAGE.md) if you are already familiar with the concept and just want to get started building CQRS applications.

By focusing on how the state *changes*, we can better understand how our domain works.

The idea of event sourcing is to not simply store the current *state* of the application, but instead store each historical *change* to the state. We call such changes ‘events.’

There are some benefits to using this idea; the most obvious ones are perhaps immutability and auditing. When an event has been recorded, that historical information will itself never change. It makes referring to the data much simpler, and you need never worry about concurrent updates. Every event also records a timestamp and a username which can be very useful metadata for auditing.

Event sourcing also allows creating independent *projections* of the state. You can replay all the changes at any time, and maintain a different storage location with an alternate view into the data. For example you can gather all the current state for easy indexing and quick access. You can ignore a lot of the information, and focus on generating the data structure that makes your particular use case simple and performant.

Event Sourcing is a product of Domain-Driven Design (DDD). In DDD, we have two carriers of state: the value object and the entity.

## Value Objects

A value object is (as the term implies) an object that represents a specific value. Values never change; they are what they are. If the value “five” was suddenly worth 4 the world would have a big problem. Value objects are therefore necessarily immutable. This is particularly useful for avoiding bugs in programming:

1. Immutable objects can be passed around the code without worry about wierd changes to their state. Shared mutable state is a great big source of bugs, but objects that cannot change will not be their cause.
2. Immutable objects (that conform to `Hashable`) can be used in sets and as dictionary keys. A mutable object would be impossible to find in such a structure as its hashcode would not match its position after it's been changed. Immutability is necessary to guarantee correct behaviour of these structures.

Value objects typically have two functions: they can be compared for structural equality, and they can be validated for correct user input.

It should not be possible to instantiate an invalid value object. The constructor (or factory) should prevent such, typically by throwing an exception or returning a failure result when invalid data is encountered. (A `Result<T>` enum might be used for this.) If the programmer can trust that all instances are valid, they will not need to validate the data again in their code; it is enough to declare that a variable must be of the correct type (and not `null`).

Value objects can also be used in calculations. You might for example `Add()` (or `+`) two numeric value objects to get their sum. Or you might multiply a value object with a scalar (e.g. a `Money` amount and an interest rate). The result of a calculation is typically an object of the same type as the input, but it could be otherwise. `Ingredient1` combined with `Ingredient2` might for example produce a `Cake`.

Value objects should also be encapsulated. They should have an internal representation of data and an external interface. Users of the value object should only ever couple to the interface, never to the concrete data representation. That allows the storage strategy to change without breaking references to the value object. And it also helps the programmer stay focused on the *meaning* of the value rather than its *composition*.

How should you for example represent a monetary amount? $1.50 can be represented in at least three different ways: as the number `150` (cents), the number `1.5` (dollars) or the two numbers: `1` (dollar) and `50` (cents). Which representation is the right one? Maybe one is right at the beginning, but becomes a problem after new requirements come to light? Encapsulation of this amount in a `Money` value object will prevent errors in all code that refer to it; if there is an error will surely be located in the `Money` class itself which makes it easier to find and correct.

Here is an interesting talk about value objects: <https://www.youtube.com/watch?v=vh-LT1mkIz4>

## Entities

Not everything can be made immutable. If it were, we would have little (if any) use of software. We will always need to gather new data and update existing data. We will need to support business processes and user tasks, both of which rely heavily on *changing* the data stored in the system. Without data changes, the usefulness of the system would be very limited.

But rather than manipulating *data*, in its specific format and structure, Domain-Driven Design (DDD) teaches us to focus on what that data *means* conceptually and/or metaphorically. And why and how it changes. The formatting and structure of the data can be altered in many ways and still represent the same meaning; the same state.

DDD separates the state of the system into parts called entities; the state of the system is the aggregated state of all entities. Each `Entity` defines invariants that must be maintained. Like value objects, entities should be encapsulated. The interface of an `Entity` should only expose meaningful operations, not direct state/data manipulation. If an action executes an operation that is invalid/unsupported for its current state, the `Entity` should throw an exception (or return a failure result).

Unlike value objects, entities possess an identifier. Since the `Entity` is stateful, there must be a way to identify which entity to modify. To summarise there are three main differences between value objects and entities:

1. Value objects are immutable while entities are stateful.
2. A value object has meaning while an entity has an identity.
    - Comparisons between value objects look at their entire structure,
      while comparisons between entities only concern their ids.
3. Value objects are often and easily discarded and recreated while entities live on for a long time.

## Events

DDD teaches us to focus on how the business processes *change* the state rather than just what the state is at any given time. By focusing on how and why the state changes we can better understand how our domain works.

This library employs event sourcing, which means that we define the state of an entity by listing all the changes that have been made to it since it was first added to the system/application. These changes are referred to as ‘events.’ Each `Event` has a name that identifies in what way the entity changed, and a fixed structure that specifies the details. It also includes which user caused the change and at what time.

A CQRS solution can synchronise (project) the events into a searchable query database. When the projection/query database is first set up, all the existing events should be processed in order. As new events are later published, the projection server should pick them up and update the query database accordingly.

It is also well defined what the state was at any point of time in the past. This fact can be used to debug the system. The events up to a given point in time can be copied to a new database and then used to recreate the system state at that time. Then experimentation can find the bug allowing it to be fixed.

Projection can be used for other purposes than the Query side of CQRS. It can for example be used to communicate between bounded contexts. Or it can be used to generate one-off reports. Or myriad other things.

## What About Aggregates?

Aggregate (as a noun) is a redundant term and not used here. The term aggregate is replaced with `Entity` in this library. See [An In-Depth Discussion on Aggregates](./AGGREGATES.md) for some arguments for this choice.

Note: The `Entity` only refers to the aggregate root. It is up to the developer to define child entity and implement the coupling between them and their root. Their state should be modeled by the root entities events, so operations on entities must add to its `UnpublishedEvents`, and replaying the events must propagate to the child entities or they won't be able to make decisions based on their state.

There is an example of how it might be acheived in the test case `Segerfeldt.EventStore.Source.Tests.AggregateTests`. Please do not take it as canon though; it is not meant to be a guide to the best ever implementation (or even necessarily a good one). It was written merely to ensure that it is at all possible. Your own implementation will probably be much better for your situation.

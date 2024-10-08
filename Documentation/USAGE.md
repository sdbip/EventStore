# EventStore Usage

This document is meant to help develop clients that employ the EventSourcing package. If you are not familiar with event sourcing, you should probably read the [documentation describing the concepts](./ES.md) first.

The EventStore model has been implemented as two separate targets. The Source target is used on the Command (write model) side of a CQRS solution, and the Projection target is used to synchronise the Source data with the Query side. There is currently no web server implementation included in EventStore, so the developer is free to use any web platform they desire. You might want to try [Vapor](https://vapor.codes) or [Webber](https://github.com/swifweb/webber).

## Source

The Source target is meant to implement the Command side (a.k.a. the write model) of a CQRS system. Import this in your web service code to start manipulating entities and publishing events.

Other than setting up the web server and endpoints, implementing a Source service is rather simple. For each command request, all you have to do is reconstitute an `Entity` (or sometimes several) through an `EntityStore` object, call relevant operations on the loaded `Entity` and finally pass the `Entity` to an `EventPublisher`. Once that is done, the `Entity` object should be discarded as it only represents a specific version (now obsolete) of the domain entity.

If another user (or automated process) has published new changes between your read and your publish, the `EventPublisher` will throw the `DomainError.concurrentUpdate` error and you can choose to retry the operation (reconstitute the new version from the `EntityStore`, repeat the changes, and publish again). Or you can abort the operation and return a `409 CONFLICT` status code to the client.

The `Entity` should define a number of events, and calling its operations should add them to its `unpublishedEvents` list; these are the events that will be published by the `EventPublisher`. The `replay()` method should parse the event data of previously published events and update internal properties as needed for the entity's operations to make the right decisions when called.

Define your command endpoints according to your web service's needs.

```swift
import Source

// It is recommended to separate commands and entities in different packages
import Domain

// The command is typically a JSON-formatted DTO passed in a request body (though your implementation might be different).
struct IncrementCounter: Codable { var amount: Int }

let entityStore = EntityStore(MyEntityStoreRepository())
let eventPublisher = EventPublisher(MyEventPublisherRepository())

// This signature is illustrative; it will probably not match how you define endpoints for your web service
func incrementCounter(
        _ id: EntityId,
        command: IncrementCounter,
        context: HttpContext) throws -> HttpResponse {

    // The logged in user is the actor that is changing the state.
    // Return 401 UNAUTHORIZED if the user/actor is not known
    guard let actor = context.username else { return .unauthorized }

    // Return 403 FORBIDDEN if the user/actor is not authorised to run the command
    guard isAuthorized(actor) else { return .forbidden }

    // Load the current state of the Entity from the EntityStore
    // If the counter is not found, return 404 NOT FOUND
    guard let counter = try entityStore.reconstituteEntity(id) as Counter else { return .notFound }

    // Convert the command input to value objects
    // Return 400 BAD REQUEST if the values are invalid.
    guard let amount = Amount(value: command.amount) else { return .badRequest }

    // Call operations on the entity
    counter.increment(by: amount)

    do {
        // Publish the new events to update the entity's state
        try eventPublisher.publishChanges(to: counter, actor: actor)
        // Return 200 OK (with payload) or 204 NO CONTENT (without payload).
        return .noContent
    } catch DomainError.concurrentUpdate {
        // If the event publisher throws concurrentUpdate, another user/process
        // has updated this entity in the time it took to run tis command.
        // Return 409 CONFLICT to indicate this to the client.
        return .conflict
    }
}
```

It is the responsibliity of the `Entity` to allow or disallow specific actions based on its current state (though generally not to handle user privileges):

```swift
import Source

public struct Amount {
    // The amount value is stored as an immutable property.
    // You should never allow mutation in a value object.
    public let value: Int

    public init(of value: Int) {
        // Check that the input is acceptable. Return nil (or throw an error) if it is not.
        // This makes it impossible to instantiate the Amount object with an invalid
        // value, and Amount instances will need no further validation.
        guard value > 0 else { return nil }

        self.value = value;
    }
}

public final class Counter: Entity {

    // Conformance requires a typeId. This should be unique to this class
    public static let typeId = "Counter"
    public let snapshotId: SnapshotId

    public var unpublishedEvents: [UnpublishedEvent] = []

    public init(snapshotId: SnapshotId) {
        self.snapshotId = snapshotId
    }

    // Adding a static New() method for creating new entities is recommended.
    // New entities should usually define initial state information and add events accordingly.
    public static new(entityId: EntityId) -> Counter {
        // Always use EntityVersion.notSaved as the version for new entities.
        // This indicates that the entity does not exist yet in the database.
        var counter = Counter(SnapshotId(entityId: entityId, version: .notSaved));
        counter.unpublishedEvents.append(UnpublishedEvent("Registered", EmptyDetails()));
        return counter;
    }

    // Implement operations for manipulating the state
    public func increment(by amount: Amount) {
        // Add an UnpublishedEvent to indicate the change.
        // You could probably pass the Amount value as-is here, but it would not be
        // recommended as the domain class should always be safe to refactor.
        // The event structure however should never be allowed to change (as that would
        // make old and new details incompatible).
        unpublishedEvents.append(UnpublishedEvent("IncrementedBy", IncrementedByDetails(amount: amount.value)))
    }

    public func replay(_ event: PublishedEvent) {
        // Update internal fields as needed to enforce domain rules.
    }

    public struct IncrementedByDetails { let amount: Int }
}
```

## Projection

The Projection target is meant to implement the Command/Query side synchronisation for a CQRS system. This model is even simpler than the Source. An `Entity` in the Projection target is simply a value object that identifies the entity in question. And there is only one `Event` type.

An `EventSource` object should be set up with a list of `Receptacle` objects. The `EventSource` should then be asked periodically to `projectEvents(maxCount: Int)`. This will find a maximum of `count` events read from the Source database and project them to the receptacles. A `PositionDelegate` is used to persist metadata on which events have already been processsed so they will not be reporocessed after a restart.

A Receptacle might be implemented similar to the following.

```swift
import Projection

public struct IncrementDTO: Decodable { var amount: Int }

public final class CounterState : Receptacle {

    // Inform the EventSource which events you handle
    public let handledEvents = ["Incremented"]

    // This will be called for every new event
    public func receive(_ event: Event) {

        // This should usually update a projection database.
        if event.name == "Registered" {
            insertCounterRow(event.entity.id)
        } else if event.name = "Incremented" {
            guard let details = try? event.details(as: IncrementDTO.self) else { return }
            incrementAmount(by: details.amount, forCounterRowWithId: entityId)
        }
    }
}
```

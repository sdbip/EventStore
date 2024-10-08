# EventStore Usage

This document is meant to help develop clients that employ the EventSourcing package. If you are not familiar with event sourcing, you should probably read the [documentation describing the concepts](./ES.md) first.

The EventStore model has been implemented as two separate targets. The Source target is used on the Command (write model) side of a CQRS solution, and the Projection target is used to synchronise the Source data with the Query side. There is currently no web server implementation included in EventStore, so the developer is free to use any web platform they desire. You might want to try [Vapor](https://vapor.codes) or [Webber](https://github.com/swifweb/webber).

## Source

The Source target is meant to implement the Command side (a.k.a. the write model) of a CQRS system. Import this in your web service code to start manipulating entities and publishing events.

Other than setting up the web server and endpoints, implementing a Source service is rather simple. For each command request, all you have to do is reconstitute an `Entity` (or sometimes several) through an `EntityStore` object, call relevant operations on the loaded `Entity` and finally pass the `Entity` to an `EventPublisher`. Once that is done, the `Entity` object should be discarded as it only represents a specific version (now obsolete) of the domain entity.

If another user (or automated process) has published new changes between your read and your publish, the `EventPublisher` will throw the `DomainError.concurrentUpdate` error and you can choose to retry the operation (reconstitute the new version from the `EntityStore`, repeat the changes, and publish again). Or you can abort the operation and return a `5xx` status to the client.

The `Entity` should define a number of events, and calling its operations should add them to its `unpublishedEvents` list; these are the events that will be published by the `EventPublisher`. The `replay()` method should parse the event data of previously published events and update internal properties as needed for the entity's operations to make the right decisions when called.

## Projection

The Projection target is meant to implement the Command/Query side synchronisation for a CQRS system. This model is even simpler than the Source. An `Entity` in the Projection target is simply a value object that identifies the entity in question. And there is only one `Event` type.

An `EventSource` object should be set up with a list of `Receptacle` objects. The `EventSource` should then be asked periodically to `projectEvents(maxCount: Int)`. This will find a maximum of `count` events read from the Source database and project them to the receptacles. A `PositionDelegate` is used to persist metadata on which events have already been processsed so they will not be reporocessed after a restart.

import Foundation

/// The object that publishes new events allowing the state of an ``Entity`` to move forward.
///
/// Typically used in concert with an ``EntityStore``:
/// ```
/// let store: EntityStore = ...
/// let publisher: EventPublisher = ...
///
/// let entity = try store.reconstituteEntity("the id") as MyEntityType
/// entity.state.performOperations()
/// try publisher.publishChanges(to: entity, actor: "the user")
/// ```
///
/// Can also be used to create and store new entities
/// ```
/// let publisher: EventPublisher = ...
///
/// let entity = MyEntityType(id: "the id")
/// try publisher.publishChanges(to: entity, actor: "the user")
/// ```
///
/// Or use ``publishConcurrencySafeEvent(_:entityId:typeId:actor:)`` to publish an event that doesn't care about prior state:
/// ```
/// let publisher: EventPublisher = ...
///
/// guard let entity: MyEntityType = try store.reconstituteEntity("the id") else { throw #{an error}# }
/// entity?.state.performOperations()
/// try publisher.publish(UnpublishedEvent(...), forId: "the id", type: "the type of the entity", actor: "the user")
/// ```
public struct EventPublisher {
    private let repository: EventPublisherRepository

    /// Initializes an ``EventPublisher`` with a backing database adapter.
    public init(repository: EventPublisherRepository) {
        self.repository = repository
    }

    /// Publishes the changes (new events) of an entity
    ///
    /// - Throws: If the entity has already been updated (by another process) since it was reconstituted.
    /// - Throws: If the database operation fails
    public func publishChanges<EntityType: Entity>(to entity: EntityType, actor: String) throws {
        try publish(
            events: entity.unpublishedEvents,
            entityId: entity.id, entityType: EntityType.typeId,
            actor: actor) {
            v in v == entity.version.value
        }
    }

    /// Publishes a single event without checking for concurrent updates.
    ///
    /// Useful if the event does not depend on the current state. A player, for
    /// example, might be rewarded a number of points for some achievement, If
    /// the event details the number of added points, rather than the new
    /// score, mutiple processes can update the score at he same time without
    /// needing to manage concurrency,
    ///
    /// - Throws: If the database operation fails
    public func publishConcurrencySafeEvent(_ event: UnpublishedEvent, entityId id: String, typeId: String, actor: String) throws {
        try publish(events: [event], entityId: id, entityType: typeId, actor: actor, isExpectedVersion: { _ in true })
    }

    private func publish(events: [UnpublishedEvent], entityId: String, entityType: String, actor: String, isExpectedVersion: (Int32?) -> Bool) throws {
        try repository.transaction {
            let currentVersion = try repository.version(ofEntityRowWithId: entityId)
            guard isExpectedVersion(currentVersion) != false else { throw DomainError.concurrentUpdate }

            if let currentVersion = currentVersion {
                try repository.setVersion(Int32(events.count) + currentVersion, onEntityRowWithId: entityId)
            } else {
                try repository.insertEntityRow(id: entityId, type: entityType, version: Int32(events.count))
            }

            let nextPosition = try repository.nextPosition()

            var nextVersion = (currentVersion ?? -1) + 1
            for event in events {
                try repository.insertEventRow(
                    entityId: entityId,
                    name: event.name,
                    jsonDetails: event.jsonDetails,
                    actor: actor,
                    version: nextVersion,
                    position: nextPosition)
                nextVersion += 1
            }
        }
    }
}

public enum DomainError: Error {
    case concurrentUpdate
}

import Foundation

public struct EventPublisher {
    private let repository: EventPublisherRepository

    public init(repository: EventPublisherRepository) {
        self.repository = repository
    }

    public func publishChanges<State>(entity: Entity<State>, actor: String) async throws where State: EntityState {
        try await publish(events: entity.state.unpublishedEvents, entityId: entity.id, entityType: State.typeId, actor: actor) {
            v in v == entity.version.value
        }
    }

    public func publish(_ event: UnpublishedEvent, forId id: String, type: String, actor: String) async throws {
        try await publish(events: [event], entityId: id, entityType: type, actor: actor, isExpectedVersion: { _ in true })
    }

    private func publish(events: [UnpublishedEvent], entityId: String, entityType: String, actor: String, isExpectedVersion: (Int32?) -> Bool) async throws {
        try await repository.transaction {
            let currentVersion = try await repository.version(ofEntityRowWithId: entityId)
            guard isExpectedVersion(currentVersion) != false else { throw DomainError.concurrentUpdate }

            if let currentVersion = currentVersion {
                try await repository.setVersion(Int32(events.count) + currentVersion, onEntityRowWithId: entityId)
            } else {
                try await repository.insertEntityRow(id: entityId, type: entityType, version: Int32(events.count))
            }

            var nextPosition = try await repository.nextPosition()
            try await repository.setNextPosition(nextPosition + Int64(events.count))

            var nextVersion = (currentVersion ?? -1) + 1
            for event in events {
                try await repository.insertEventRow(
                    entityId: entityId,
                    entityType: entityType,
                    name: event.name,
                    jsonDetails: event.jsonDetails,
                    actor: actor,
                    version: nextVersion,
                    position: nextPosition)
                nextVersion += 1
                nextPosition += 1
            }
        }
    }
}

public enum DomainError: Error {
    case concurrentUpdate
}

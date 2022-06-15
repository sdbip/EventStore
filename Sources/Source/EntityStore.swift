import Foundation

/// The tool for reconstituting entities from their published events.
///
/// Use in concert with an ``EventPublisher``:
/// ```
/// let store: EntityStore = ...
/// let publisher: EventPublisher = ...
///
/// let entity = try store.reconstitute(entityWithId: "the id") as Entity<MyEntityState>
/// entity.state.performOperations()
/// try publisher.publishChanges(entity)
/// ```
public struct EntityStore {
    private let repository: EntityStoreRepository

    /// Initializes an ``EntityStore`` with a backing database adapter.
    public init(repository: EntityStoreRepository) {
        self.repository = repository
    }

    /// Get the stored type-name for the entity with a given id
    public func type(ofEntityWithId id: String) throws -> String? {
        return try repository.type(ofEntityRowWithId: id)
    }

    /// Reconstitute an entity from its published events.
    ///
    /// - Throws: if the associated ``EntityState`` has the wrong `type` identifier.
    /// - Throws: If the database operation fails
    public func reconstitute<EntityType: Entity>(entityWithId id: String) throws -> EntityType? {
        guard let history = try history(forEntityWithId: id) else { return nil }
        return try history.entity()
    }

    /// Fetch the entire history of an ``Entity``
    ///
    /// - Throws: If the database operation fails
    public func history(forEntityWithId id: String) throws -> History? {
        guard let entityRow = try repository.entityRow(withId: id) else { return nil }
        let eventRows = try repository.allEventRows(forEntityWithId: id).map {
            PublishedEvent(name: $0.name, details: $0.details, actor: $0.actor, timestamp: Date(julianDay: $0.timestamp))
        }
        return History(id: entityRow.id, type: entityRow.type, events: eventRows, version: .eventCount(entityRow.version))
    }
}

// Swift reference date is January 1, 2001 CE @ 0:00:00
// Julian Day 0 is November 24, 4714 BCE @ 12:00:00
// Those dates are 2451910.5 days apart.
private let julianDayAtReferenceDate = 2451910.5
private let secondsPerDay = 86_400.0
extension Date {
    init(julianDay: Double) {
        let timeInterval = (julianDay - julianDayAtReferenceDate) * secondsPerDay
        self.init(timeIntervalSinceReferenceDate: timeInterval)
    }
}

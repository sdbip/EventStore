import Foundation

public struct EntityStore {
    private let repository: EntityStoreRepository

    public init(repository: EntityStoreRepository) {
        self.repository = repository
    }

    public func type(ofEntityWithId id: String) async throws -> String? {
        return try await repository.type(ofEntityRowWithId: id)
    }

    public func reconstitute<State: EntityState>(entityWithId id: String) async throws -> Entity<State>? {
        guard let history = try await history(forEntityWithId: id) else { return nil }
        return try history.entity()
    }

    public func history(forEntityWithId id: String) async throws -> History? {
        guard let entityRow = try await repository.entityRow(withId: id) else { return nil }
        let eventRows = try await repository.allEventRows(forEntityWithId: id).map {
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

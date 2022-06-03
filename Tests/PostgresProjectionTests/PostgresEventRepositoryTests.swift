import XCTest

import Postgres
import PostgresProjection
import PostgresSource
import Projection

final class PostgresEventRepositoryTests: XCTestCase {
    var database: Database!

    override func setUp() async throws {
        database = try await setUpEmptyTestDatabase()
    }

    func test_readEventsAfter_returnsEvents() async throws {
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)

        let events = try await database.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events,
            [Event(
                entity: Entity(id: "entity", type: "type"),
                name: "name",
                details: "{}",
                position: 1
            )])
    }

    func test_readEventsAfter_returnsOnlyEventsAtLaterPositions() async throws {
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try await database.readEvents(maxCount: 3, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1, 2])
    }

    func test_readEventsAfter_returnsAllEventsWhenNoPositionSpecified() async throws {
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try await database.readEvents(maxCount: 3, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1, 2])
    }

    func test_readEventsFromBeginning_returnsNoMoreThanMaxCountEvents() async throws {
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try await database.readEvents(maxCount: 2, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1])
    }

    func test_readEventsAfter_returnsNoMoreThanMaxCountEvents() async throws {
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try await database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try await database.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1])
    }
}

extension Event: Equatable {
    public static func ==(left: Event, right: Event) -> Bool {
        return left.entity == right.entity &&
        left.name == right.name &&
        left.jsonDetails == right.jsonDetails &&
        left.position == right.position
    }
}

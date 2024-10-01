import XCTest

import Postgres
import PostgresProjection
import PostgresSource
import Projection

final class PostgresEventRepositoryTests: XCTestCase {
    var database: Database!

    override func setUp() async throws {
        database = try setUpEmptyTestDatabase()
        try database.insertEntityRow(id: "entity", type: "a type", version: 1)
    }

    func test_readEventsAfter_returnsEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)

        let events = try database.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events,
            [Event(
                entity: Entity(id: "entity", type: "type"),
                name: "name",
                details: "{}",
                version: 1,
                position: 1
            )])
    }

    func test_readEventsAfter_returnsOnlyEventsAtLaterPositions() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try database.readEvents(maxCount: 3, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1, 2])
    }

    func test_readEventsAfter_returnsAllEventsWhenNoPositionSpecified() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try database.readEvents(maxCount: 3, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1, 2])
    }

    func test_readEventsFromBeginning_returnsNoMoreThanMaxCountEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try database.readEvents(maxCount: 2, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1])
    }

    func test_readEventsAfter_returnsNoMoreThanMaxCountEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try database.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1])
    }
}

extension Event: @retroactive Equatable {
    public static func ==(left: Event, right: Event) -> Bool {
        return left.entity == right.entity &&
        left.name == right.name &&
        left.jsonDetails == right.jsonDetails &&
        left.version == right.version &&
        left.position == right.position
    }
}

import SQLite3
import XCTest

import Projection
import SQLite
import SQLiteProjection
import SQLiteSource

private let testDBFile = "test.db"

final class SQLiteEventRepositoryTests: XCTestCase {
    var database: Database!

    override func setUp() {
        _ = try? FileManager.default.removeItem(atPath: testDBFile)

        do {
            database = try Database(openFile: testDBFile)

            try Schema.add(to: testDBFile)
            try database.insertEntityRow(id: "entity", type: "type", version: 0)
        } catch {
            XCTFail("\(error)")
        }
    }

    override func tearDown() {
        _ = try? database.close()
        _ = try? FileManager.default.removeItem(atPath: testDBFile)
    }

    func test_readEventsAfter_returnsEvents() throws {
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 1, position: 1)

        let events = try database.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events,
            [Event(
                entity: Entity(id: "entity", type: "type"),
                name: "name",
                details: "{}",
                ordinal: 1,
                position: 1
            )])
    }

    func test_readEventsAfter_returnsOnlyEventsAtLaterPositions() throws {
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 0, position: 0)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 1, position: 1)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 2, position: 2)

        let events = try database.readEvents(maxCount: 3, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1, 2])
    }

    func test_readEventsAfter_returnsAllEventsWhenNoPositionSpecified() throws {
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 0, position: 0)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 1, position: 1)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 2, position: 2)

        let events = try database.readEvents(maxCount: 3, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1, 2])
    }

    func test_readEventsFromBeginning_returnsNoMoreThanMaxCountEvents() throws {
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 0, position: 0)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 1, position: 1)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 2, position: 2)

        let events = try database.readEvents(maxCount: 2, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1])
    }

    func test_readEventsAfter_returnsNoMoreThanMaxCountEvents() throws {
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 0, position: 0)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 1, position: 1)
        try database.insertEventRow(entityId: "entity", name: "name", jsonDetails: "{}", actor: "actor", ordinal: 2, position: 2)

        let events = try database.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1])
    }
}

extension Event: @retroactive Equatable {
    public static func ==(left: Event, right: Event) -> Bool {
        return left.entity == right.entity &&
        left.name == right.name &&
        left.jsonDetails == right.jsonDetails &&
        left.ordinal == right.ordinal &&
        left.position == right.position
    }
}

import SQLite3
import XCTest

import Projection
import SQLiteProjection
import SQLiteSource
import SQLite

private let testDBFile = "test.db"

final class SQLiteEventRepositoryTests: XCTestCase {
    var repository: SQLiteEventRepository!
    var database: Database!

    override func setUp() {
        _ = try? FileManager.default.removeItem(atPath: testDBFile)

        do {
            repository = SQLiteEventRepository(file: testDBFile)
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

    func test_readEventsAt_returnsEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)

        let events = try repository.readEvents(at: 1)

        XCTAssertEqual(events,
            [Event(
                entity: Entity(id: "entity", type: "type"),
                name: "name",
                details: "{}",
                position: 1
            )])
    }

    func test_readEventsAt_returnsOnlyEventsAtTheIndicatedPosition() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try repository.readEvents(at: 1)

        XCTAssert(events.allSatisfy({ $0.position == 1 }))

    }

    func test_readEventsAfter_returnsEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)

        let events = try repository.readEvents(maxCount: 1, after: 0)

        XCTAssertEqual(events,
            [Event(
                entity: Entity(id: "entity", type: "type"),
                name: "name",
                details: "{}",
                position: 1
            )])
    }

    func test_readEventsAfter_returnsOnlyEventsAtLaterPositions() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try repository.readEvents(maxCount: 3, after: 0)

        XCTAssertEqual(events.map { $0.position }, [1, 2])
    }

    func test_readEventsAfter_returnsAllEventsWhenNoPositionSpecified() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try repository.readEvents(maxCount: 3, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1, 2])
    }

    func test_readEventsFromBeginning_returnsNoMoreThanMaxCountEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try repository.readEvents(maxCount: 2, after: nil)

        XCTAssertEqual(events.map { $0.position }, [0, 1])
    }

    func test_readEventsAfter_returnsNoMoreThanMaxCountEvents() throws {
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 0, position: 0)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 1, position: 1)
        try database.insertEventRow(entityId: "entity", entityType: "type", name: "name", jsonDetails: "{}", actor: "actor", version: 2, position: 2)

        let events = try repository.readEvents(maxCount: 1, after: 0)

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

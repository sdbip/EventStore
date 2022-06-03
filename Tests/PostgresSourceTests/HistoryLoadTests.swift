import XCTest
import PostgresClientKit

import Postgres
import PostgresSource
import Source

final class HistoryLoadTests: XCTestCase {
    var store: EntityStore!
    var database: Database!

    override func setUp() async throws {
        database = try setUpEmptyTestDatabase()
        store = EntityStore(repository: database)
    }
    
    func test_fetchesEntityData() async throws {
        try database.operation(#"INSERT INTO "Entities" ("id", "type", "version") VALUES ('test', 'TheType', 42)"#).execute()

        let history = try await store.history(forEntityWithId: "test")
        XCTAssertEqual(history?.type, "TheType")
        XCTAssertEqual(history?.version, 42)
    }

    func test_fetchesEventData() async throws {
        try database.insertEntityRow(id: "test", type: "TheType", version: 42)
        try database.insertEventRow(entityId: "test", entityType: "TheType", name: "TheEvent", jsonDetails: "{}", actor: "a_user", version: 0, position: 0)

        guard let history = try await store.history(forEntityWithId: "test") else { return XCTFail("No history returned") }

        XCTAssertEqual(history.events.count, 1)

        XCTAssertEqual(history.events[0].name, "TheEvent")
        XCTAssertEqual(history.events[0].jsonDetails, "{}")
        XCTAssertEqual(history.events[0].actor, "a_user")
    }

    func test_convertsTimestampFromJulianDay() async throws {
        try database.insertEntityRow(id: "test", type: "TheType", version: 42)
        try database.operation("""
            INSERT INTO "Events" ("entityId", "entityType", "name", "details", "actor", "timestamp", "version", "position") VALUES
                ('test', 'TheType', 'any', '{}', 'any', 2459683.17199667, 0, 0)
            """
        ).execute()

        guard let history = try await store.history(forEntityWithId: "test") else { return XCTFail("No history returned") }
        guard let event = history.events.first else { return XCTFail("No event returned")}

        XCTAssertEqual("\(formatWithMilliseconds(date: event.timestamp))", "2022-04-13 16:07:40.515 +0000")
    }

    private func formatWithMilliseconds(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
        return dateFormatter.string(from: date)
    }
}

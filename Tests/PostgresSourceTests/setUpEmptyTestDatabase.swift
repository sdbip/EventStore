import XCTest
import PostgresNIO

import Postgres
import PostgresSource
import Source

let host = Host(
    "localhost",
    database: ProcessInfo.processInfo.environment["POSTGRES_TEST_DATABASE"]!,
    useSSL: false)
let credentials = Credentials(
    username: ProcessInfo.processInfo.environment["POSTGRES_TEST_USER"]!,
    password: ProcessInfo.processInfo.environment["POSTGRES_TEST_PASS"])

var eventLoopGroup: MultiThreadedEventLoopGroup!

var database: Database!

public func setUpEmptyTestDatabase() async throws -> Database {
    if database == nil {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        try await createTestDatabase()

        database = try await Database.connect(on: eventLoopGroup.next(), host: host, credentials: credentials)
    }

    try await Schema.add(to: database)
    try await database.execute(#"DELETE FROM "Events""#)
    try await database.execute(#"DELETE FROM "Entities""#)
    try await database.execute(#"UPDATE "Properties" SET "value" = 0 WHERE "name" = 'next_position'"#)

    return database
}

private func createTestDatabase() async throws {
    var noDbHost = host
    noDbHost.database = nil
    let noDb = try await Database.connect(on: eventLoopGroup.next(), host: noDbHost, credentials: credentials)
    _ = try? await noDb.execute(PostgresQuery(unsafeSQL: "CREATE DATABASE \(host.database!)"))
}

import Source
import Postgres

extension Database: EventPublisherRepository {
    public func transaction<T>(do block: () async throws -> T) async throws -> T {
        try await execute("BEGIN")
        do {
            let result = try await block()
            try await execute("COMMIT")
            return result
        } catch {
            try await execute("ROLLBACK")
            throw error
        }
    }

    public func insertEntityRow(id: String, type: String, version: Int32) async throws {
        try await execute("""
            INSERT INTO "Entities" ("id", "type", "version") VALUES (\(id), \(type), \(version))
            """)
    }

    public func insertEventRow(entityId: String, entityType: String, name: String, jsonDetails: String, actor: String, version: Int32, position: Int64) async throws {
        try await execute(
            """
            INSERT INTO "Events" ("entityId", "entityType", "name", "details", "actor", "version", "position")
            VALUES (\(entityId), \(entityType), \(name), \(jsonDetails), \(actor), \(version), \(position))
            """
        )
    }

    public func nextPosition() async throws -> Int64 {
        try await single("""
            SELECT "value" FROM "Properties" WHERE "name" = \("next_position")
            """, as: String.self)
        .flatMap(Int64.init)!
    }

    public func setNextPosition(_ position: Int64) async throws {
        try await execute("""
        	UPDATE "Properties" SET "value" = \(position) WHERE "name" = 'next_position'
        	""")
    }

    public func version(ofEntityRowWithId id: String) async throws -> Int32? {
        return try await single("""
        	SELECT "version" FROM "Entities" WHERE "id" = \(id)
        	""", as: Int32.self)
    }

    public func setVersion(_ version: Int32, onEntityRowWithId id: String) async throws {
        try await execute("""
            UPDATE "Entities" SET "version" = \(version) WHERE id = \(id)
            """)
    }
}

import Source
import Postgres

extension Database: EventPublisherRepository {
    public func transaction<T>(do block: () async throws -> T) async throws -> T {
        try operation("BEGIN").execute()
        do {
            let result = try await block()
            try operation("COMMIT").execute()
            return result
        } catch {
            try operation("ROLLBACK").execute()
            throw error
        }
    }

    public func insertEntityRow(id: String, type: String, version: Int32) throws {
        try operation(#"INSERT INTO "Entities" ("id", "type", "version") VALUES ($1, $2, $3)"#, parameters: id, type, Int(version))
            .execute()
    }

    public func insertEventRow(entityId: String, entityType: String, name: String, jsonDetails: String, actor: String, version: Int32, position: Int64) throws {
        try operation(
            """
            INSERT INTO "Events" ("entityId", "entityType", "name", "details", "actor", "version", "position")
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            """,
            parameters:
            entityId,
            entityType,
            name,
            jsonDetails,
            actor,
            Int(version),
            Int(position)
        ).execute()
    }

    public func nextPosition() throws -> Int64 {
        try operation(#"SELECT "value" FROM "Properties" WHERE "name" = 'next_position'"#)
            .single { try Int64($0[0].int()) }!
    }

    public func setNextPosition(_ position: Int64) throws {
        try operation(#"UPDATE "Properties" SET "value" = $1 WHERE "name" = 'next_position'"#, parameters: Int(position))
            .execute()
    }

    public func version(ofEntityRowWithId id: String) throws -> Int32? {
        return try operation(#"SELECT "version" FROM "Entities" WHERE "id" = $1"#, parameters: id)
            .single { try Int32($0[0].int()) }
    }

    public func setVersion(_ version: Int32, onEntityRowWithId id: String) throws {
        try operation(#"UPDATE "Entities" SET "version" = $1 WHERE id = $2"#, parameters: Int(version), id)
            .execute()
    }
}


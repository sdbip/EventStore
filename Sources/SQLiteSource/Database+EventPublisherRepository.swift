import Source
import SQLite

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
        try operation("INSERT INTO Entities (id, type, version) VALUES (?, ?, ?)", id, type, version)
            .execute()
    }

    public func insertEventRow(entityId: String, entityType: String, name: String, jsonDetails: String, actor: String, version: Int32, position: Int64) throws {
        try operation("INSERT INTO Events (entityId, entityType, name, details, actor, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
            entityId,
            entityType,
            name,
            jsonDetails,
            actor,
            version,
            position
        ).execute()
    }

    public func nextPosition() throws -> Int64 {
        try operation("SELECT value FROM Properties WHERE name = 'next_position'")
            .single(read: { $0.int64(at: 0) })!
    }

    public func setNextPosition(_ position: Int64) throws {
        try operation("UPDATE Properties SET value = ? WHERE name = 'next_position'", position)
            .execute()
    }

    public func version(ofEntityRowWithId id: String) throws -> Int32? {
        return try operation("SELECT version FROM Entities WHERE id = ?", id)
            .single(read: { $0.int32(at: 0) })
    }

    public func setVersion(_ version: Int32, onEntityRowWithId id: String) throws {
        try operation("UPDATE Entities SET version = ? WHERE id = ?", version, id)
            .execute()
    }
}

import Source
import Postgres

extension Database: @retroactive EventPublisherRepository {
    public func transaction<T>(do block: () throws -> T) throws -> T {
        try operation("BEGIN").execute()
        do {
            let result = try block()
            try operation("COMMIT").execute()
            return result
        } catch {
            try operation("ROLLBACK").execute()
            throw error
        }
    }

    public func insertEntityRow(id: String, type: String, version: Int32) throws {
        try operation("INSERT INTO Entities (id, type, version) VALUES ($1, $2, $3)", parameters: id, type, Int(version))
            .execute()
    }

    public func insertEventRow(entityId: String, entityType: String, name: String, jsonDetails: String, actor: String, version: Int32, position: Int64) throws {
        try operation(
            """
            INSERT INTO Events (entity_id, entity_type, name, details, actor, version, position)
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
        try operation("SELECT max(position) + 1 FROM Events")
            .single {
                if $0[0].isNull { return 0 }
                return try Int64($0[0].int())
            }!
    }

    public func version(ofEntityRowWithId id: String) throws -> Int32? {
        return try operation("SELECT version FROM Entities WHERE id = $1", parameters: id)
            .single { try Int32($0[0].int()) }
    }

    public func setVersion(_ version: Int32, onEntityRowWithId id: String) throws {
        try operation("UPDATE Entities SET version = $1 WHERE id = $2", parameters: Int(version), id)
            .execute()
    }
}


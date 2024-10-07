import Postgres
import Source

extension Database: @retroactive EntityStoreRepository {
    public func typeId(entityRowWithId id: String) throws -> String? {
        return try operation("SELECT type FROM Entities WHERE id = 'test'")
            .single { try $0[0].string() }
    }

    public func entityRow(id: String) throws -> EntityRow? {
        return try operation("SELECT type, version FROM Entities WHERE id = $1", parameters: id)
        .single { try EntityRow(id: id, type: $0[0].string(), version: Int32($0[1].int())) }
    }

    public func allEventRows(entityId: String) throws -> [EventRow] {
        return try operation(
                """
                SELECT name, details, actor, timestamp FROM Events
                	WHERE entity_id = $1
                    ORDER BY ordinal
                """,
                parameters: entityId)
            .query {
                return try EventRow(entityId: entityId, name: $0[0].string(), details: $0[1].string(), actor: $0[2].string(), timestamp: $0[3].double())
            }
    }
}

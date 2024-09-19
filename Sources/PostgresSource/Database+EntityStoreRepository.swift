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
        return try operation("SELECT entity_type, name, details, actor, timestamp FROM Events WHERE entity_id = $1 ORDER BY version",
                             parameters: entityId)
            .query {
                let entity = try EntityData(id: entityId, type: $0[0].string())
                return try EventRow(entity: entity, name: $0[1].string(), details: $0[2].string(), actor: $0[3].string(), timestamp: $0[4].double())
            }
    }
}

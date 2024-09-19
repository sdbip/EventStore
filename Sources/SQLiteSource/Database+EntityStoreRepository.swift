import Source
import SQLite

extension Database: @retroactive EntityStoreRepository {
    public func typeId(entityRowWithId id: String) throws -> String? {
        return try operation("SELECT type FROM Entities WHERE id = 'test'")
            .single { $0.string(at: 0) }
    }

    public func entityRow(id: String) throws -> EntityRow? {
        return try operation("SELECT type, version FROM Entities WHERE id = ?", id)
        .single {
            guard let type = $0.string(at: 0) else { throw SQLiteError.message("Entity has no type") }
            return EntityRow(id: id, type: type, version: $0.int32(at: 1))
        }
    }

    public func allEventRows(entityId: String) throws -> [EventRow] {
        return try operation("SELECT entity_type, name, details, actor, timestamp FROM Events WHERE entity_id = ? ORDER BY version", entityId)
            .query {
                guard let type = $0.string(at: 0) else { throw SQLiteError.message("Event has no entityType") }
                guard let name = $0.string(at: 1) else { throw SQLiteError.message("Event has no name") }
                guard let details = $0.string(at: 2) else { throw SQLiteError.message("Event has no details") }
                guard let actor = $0.string(at: 3) else { throw SQLiteError.message("Event has no actor") }
                let entity = EntityData(id: entityId, type: type)
                return EventRow(entity: entity, name: name, details: details, actor: actor, timestamp: $0.double(at: 4))
            }
    }
}

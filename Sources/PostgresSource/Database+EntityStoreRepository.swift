import Postgres
import Source
import Foundation

extension Database: EntityStoreRepository {
    public func type(ofEntityRowWithId id: String) async throws -> String? {
        return try await single("""
            SELECT type FROM "Entities" WHERE "id" = \(id)
            """, as: String.self)
    }
    
    public func entityRow(withId id: String) async throws -> EntityRow? {
        return try await single("""
            SELECT type, version FROM "Entities" WHERE id = \(id)
            """, as: (String, Int32).self)
        .map { EntityRow(id: id, type: $0.0, version: $0.1) }
    }
    
    public func allEventRows(forEntityWithId entityId: String) async throws -> [EventRow] {
        return try await query("""
            SELECT "entityType", "name", "details", "actor", "timestamp" FROM "Events" WHERE "entityId" = \(entityId) ORDER BY "version"
            """, as: (String, String, String, String, Decimal).self)
        .map {
            let entity = EntityData(id: entityId, type: $0.0)
            return EventRow(entity: entity, name: $0.1, details: $0.2, actor: $0.3, timestamp: NSDecimalNumber(decimal: $0.4).doubleValue)
        }
    }
}

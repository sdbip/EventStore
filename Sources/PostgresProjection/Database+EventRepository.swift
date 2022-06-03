import Postgres
import Projection

extension Database: EventRepository {
    public func readEvents(maxCount: Int, after position: Int64?) async throws -> [Event] {
        let rows = try await query("""
            SELECT "entityId", "entityType", "name", "details", "position" FROM "Events" WHERE "position" > \(position ?? -1) LIMIT \(maxCount)
            """, as: (String, String, String, String, Int64).self)
        return rows.map {
            Event(
                entity: Entity(id: $0.0, type: $0.1),
                name: $0.2,
                details: $0.3,
                position: $0.4)
        }
    }
}

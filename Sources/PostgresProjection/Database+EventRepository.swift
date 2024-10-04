import Postgres
import Projection

extension Database: @retroactive EventRepository {
    public func readEvents(maxCount: Int, after position: Int64?) throws -> [Event] {
        let operation = try operation("""
            SELECT entity_id, type AS entity_type, name, details, Events.version, position
                FROM Events JOIN Entities ON Entities.id = Events.entity_id
                WHERE "position" > $1 LIMIT \(maxCount)
            """,
            parameters: Int(position ?? -1))
        return try operation.query {
            return try Event(
                entity: Entity(id: $0[0].string(), type: $0[1].string()),
                name: $0[2].string(),
                details: $0[3].string(),
                version: $0[4].int(),
                position: Int64($0[5].int()))
        }
    }
}

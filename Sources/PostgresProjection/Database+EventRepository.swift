import Postgres
import Projection

extension Database: @retroactive EventRepository {
    public func readEvents(maxCount: Int, after position: Int64?) throws -> [Event] {
        let operation = try operation("""
            SELECT entity_id, entity_type, name, details, position FROM Events WHERE "position" > $1 LIMIT \(maxCount)
            """,
            parameters: Int(position ?? -1))
        return try operation.query {
            return try Event(
                entity: Entity(id: $0[0].string(), type: $0[1].string()),
                name: $0[2].string(),
                details: $0[3].string(),
                position: Int64($0[4].int()))
        }
    }
}

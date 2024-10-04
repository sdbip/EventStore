import SQLite
import Projection

extension Database: @retroactive EventRepository {
    public func readEvents(maxCount: Int, after position: Int64?) throws -> [Event] {
        let operation = try operation("""
            SELECT entity_id, type AS entity_type, name, details, Events.version, position
            FROM Events JOIN Entities ON Entities.id = Events.entity_id
            WHERE position > $1 LIMIT \(maxCount)
            """,
            position ?? -1)
        return try operation.query {
            guard let entityId = $0.string(at: 0),
                  let type = $0.string(at: 1),
                  let name = $0.string(at: 2),
                  let details = $0.string(at: 3)
            else { throw SQLiteError.unknown }

            return Event(
                entity: Entity(id: entityId, type: type),
                name: name,
                details: details,
                version: Int($0.int32(at: 4)),
                position: $0.int64(at: 5))
        }
    }
}

public protocol EventPublisherRepository {
    func transaction<T>(do block: () async throws -> T) async throws -> T

    func insertEntityRow(id: String, type: String, version: Int32) async throws

    func insertEventRow(entityId: String, entityType: String, name: String, jsonDetails: String, actor: String, version: Int32, position: Int64) async throws

    func nextPosition() async throws -> Int64
    func setNextPosition(_ position: Int64) async throws

    func version(ofEntityRowWithId id: String) async throws -> Int32?
    func setVersion(_ version: Int32, onEntityRowWithId id: String) async throws
}

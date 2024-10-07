public protocol EventPublisherRepository {
    func transaction<T>(do block: () throws -> T) throws -> T

    func insertEntityRow(id: String, type: String, version: Int32) throws

    func insertEventRow(entityId: String, name: String, jsonDetails: String, actor: String, ordinal: Int32, position: Int64) throws

    func nextPosition() throws -> Int64

    func version(ofEntityRowWithId id: String) throws -> Int32?
    func setVersion(_ version: Int32, onEntityRowWithId id: String) throws
}

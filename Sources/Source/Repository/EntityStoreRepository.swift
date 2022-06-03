public protocol EntityStoreRepository {
    func type(ofEntityRowWithId id: String) async throws -> String?

    func entityRow(withId id: String) async throws -> EntityRow?
    func allEventRows(forEntityWithId entityId: String) async throws -> [EventRow]
}

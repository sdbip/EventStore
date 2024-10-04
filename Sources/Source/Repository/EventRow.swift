public struct EventRow {
    public let entityId: String
    public let name: String
    public let details: String
    public let actor: String
    public let timestamp: Double

    public init(entityId: String, name: String, details: String, actor: String, timestamp: Double) {
        self.entityId = entityId
        self.name = name
        self.details = details
        self.actor = actor
        self.timestamp = timestamp
    }
}

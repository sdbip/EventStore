public struct History {
    public let type: String
    public let events: [PublishedEvent]
    public let version: Int32

    public init(type: String, events: [PublishedEvent], version: Int32) {
        self.type = type
        self.events = events
        self.version = version
    }

    public func reconstitute<EntityType: Entity>() throws -> EntityType {
        guard EntityType.type == self.type else {
            throw ReconstitutionError.incorrectType
        }

        let entity = EntityType(version: self.version)
        for event in self.events { entity.apply(event) }
        return entity
    }
}

public enum ReconstitutionError: Error {
    case incorrectType
}
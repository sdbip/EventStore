/// An event notifying that the state of an entity has changed at the source
public struct Event {
    /// The entity that changed
    public let entity: Entity
    /// The name of the event, indicating in what way the entity's state has changed
    public let name: String
    /// A JSON object specifying the details of the change
    public let jsonDetails: String
    /// The ordering of this event in the entity's changes.
    public let version: Int
    /// The position of this event in the stream. Useful for keeping track after restarting the application
    public let position: Int64

    public init(entity: Entity, name: String, details: String, version: Int, position: Int64) {
        self.entity = entity;
        self.name = name;
        self.jsonDetails = details;
        self.version = version;
        self.position = position;
    }
}

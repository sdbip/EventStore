import XCTest
import Source

final class TestEntity: Entity {
    let id: String
    let version: EntityVersion
    
    static let typeId = "TestEntity"
    let unpublishedEvents: [UnpublishedEvent] = []
    var reconstitutedEvents: [PublishedEvent]?

    init(id: String, version: EntityVersion, publishedEvents events: [PublishedEvent]) {
        self.id = id
        self.version = version
        reconstitutedEvents = events
    }
}

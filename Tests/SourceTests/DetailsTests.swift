import XCTest
import Source

final class DetailsTests: XCTestCase {
    func test_writesCodableDetails() throws {
        let counter = Counter.new(id: "counter")
        counter.step(count: 10)

        XCTAssertEqual(counter.unpublishedEvents.count, 1)
        XCTAssertEqual(counter.unpublishedEvents[0].jsonDetails, #"{"count":10}"#)
    }

    func test_readsDecodableDetails() throws {
        let history = History(
            id: "counter",
            type: Counter.typeId,
            events: [
                PublishedEvent(
                    name: "DidStep",
                    details: #"{"count":10}"#,
                    actor: "whomever",
                    timestamp: Date()
                )
            ],
            version: 0)

        let counter: Counter = try history.entity()
        XCTAssertEqual(counter.currentValue, 10)
    }
}

final class Counter: Entity {    
    static let typeId = "Counter"

    let id: String
    let version: EntityVersion
    var unpublishedEvents: [UnpublishedEvent] = []
    var currentValue = 0
    
    init(id: String, version: EntityVersion, publishedEvents events: [PublishedEvent]) {
        self.id = id
        self.version = version

        if let event = events.first, event.name == "DidStep", let details = try? event.details(as: DidStepDetails.self) {
            currentValue += details.count
        }
    }

    func step(count: Int) {
        unpublishedEvents.append(try! UnpublishedEvent(encodableDetails: DidStepDetails(count: count)))
    }
}

struct DidStepDetails: EventDetails, Codable {
    static let eventName = "DidStep"

    let count: Int
}

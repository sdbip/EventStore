import XCTest
import Source

final class DetailsTests: XCTestCase {
    func test_writesCodableDetails() throws {
        let counter = Entity(id: "counter", state: Counter())
        counter.state.step(count: 10)

        XCTAssertEqual(counter.state.unpublishedEvents.count, 1)
        XCTAssertEqual(counter.state.unpublishedEvents[0].jsonDetails, #"{"count":10}"#)
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

        let counter: Entity<Counter> = try history.entity()
        XCTAssertEqual(counter.state.currentValue, 10)
    }
}

final class Counter {
    static let typeId = "Counter"
    var unpublishedEvents: [UnpublishedEvent] = []
    var currentValue = 0

    func step(count: Int) {
        unpublishedEvents.append(try! UnpublishedEvent(encodableDetails: DidStepDetails(count: count)))
    }
}

extension Counter: EntityState {
    convenience init(events: [PublishedEvent]) {
        self.init()

        let event = events[0]
        if event.name == "DidStep", let details = try? event.details(as: DidStepDetails.self) {
            currentValue += details.count
        }
    }
}

struct DidStepDetails: EventDetails, Codable {
    static let eventName = "DidStep"

    let count: Int
}

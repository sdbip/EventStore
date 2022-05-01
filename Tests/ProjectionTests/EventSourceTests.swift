import XCTest
import Projection

final class EventSourceTests: XCTestCase {
    var eventSource: EventSource!
    var repository: TransientEventRepository!
    var delegate: MockPositionDelegate!

    override func setUp() {
        repository = TransientEventRepository()
        delegate = MockPositionDelegate()
        eventSource = EventSource(repository: repository, delegate: delegate)
    }

    func test_swallowsEventIfNoReceiver() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [event(named: "UnhandledEvent")]

        try eventSource.projectEvents(count: 1)

        XCTAssertEqual(receptacle.receivedEvents, [])
    }

    func test_allowsEmptyResponseFromRepository() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = []

        try eventSource.projectEvents(count: 1)

        XCTAssertEqual(receptacle.receivedEvents, [])
    }

    func test_forwardsEventToReceiver() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [event(named: "TheEvent")]

        try eventSource.projectEvents(count: 1)

        XCTAssertEqual(receptacle.receivedEvents, ["TheEvent"])
    }

    func test_forwardsMultipleEvents() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheFirstEvent", "TheSecondEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [event(named: "TheFirstEvent"), event(named: "TheSecondEvent")]

        try eventSource.projectEvents(count: 2)

        XCTAssertEqual(receptacle.receivedEvents, ["TheFirstEvent", "TheSecondEvent"])
    }

    func test_forwardsOnlyAsManyEventsAsRequested() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheFirstEvent", "TheSecondEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [event(named: "TheFirstEvent", position: 0), event(named: "TheSecondEvent", position: 1)]

        try eventSource.projectEvents(count: 1)

        XCTAssertEqual(receptacle.receivedEvents, ["TheFirstEvent"])
    }

    func test_readsOnlyEventsAfterTheCurrentPosition() throws {
        delegate.initialPosition = 1

        let receptacle = TestReceptacle(handledEvents: ["TheFirstEvent", "TheSecondEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [
            event(named: "TheFirstEvent", position: 1),
            event(named: "TheSecondEvent", position: 2)
        ]

        try eventSource.projectEvents(count: 2)

        XCTAssertEqual(receptacle.receivedEvents, ["TheSecondEvent"])
    }

    func test_updatesPositionAfterReadingEvents() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheFirstEvent", "TheSecondEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [
            event(named: "TheFirstEvent", position: 1),
            event(named: "TheSecondEvent", position: 2)
        ]

        try eventSource.projectEvents(count: 1)
        try eventSource.projectEvents(count: 1)

        XCTAssertEqual(receptacle.receivedEvents, ["TheFirstEvent", "TheSecondEvent"])
    }
    
    func test_notifiesTheUpdatedPosition() throws {
        let receptacle = TestReceptacle(handledEvents: ["TheFirstEvent", "TheSecondEvent"])
        eventSource.add(receptacle)
        repository.nextEvents = [
            event(named: "TheFirstEvent", position: 1),
            event(named: "TheSecondEvent", position: 2)
        ]

        try eventSource.projectEvents(count: 2)

        XCTAssertEqual(delegate.lastUpdatedPosition, 2)
    }

    private func event(named name: String) -> Event {
        event(named: name, position: 0)
    }

    private func event(named name: String, position: Int64) -> Event {
        Event(
            entityId: "some_entity",
            name: name,
            entityType: "some_type",
            details: "{}",
            position: position)
    }
}

final class TransientEventRepository: EventRepository {
    var nextEvents: [Event] = []

    func readEvents(maxCount: Int, after position: Int64?) -> [Event] {
        return Array(nextEvents.drop(while: {position != nil && $0.position <= position!}).prefix(maxCount))
    }

    func readEvents(at position: Int64) -> [Event] {
        return Array(nextEvents.filter({ $0.position == position }))
    }
}

final class MockPositionDelegate: PositionDelegate {
    var initialPosition: Int64?
    var lastUpdatedPosition: Int64?
    
    func lastProjectedPosition() throws -> Int64? {
        return initialPosition
    }

    func update(position: Int64) {
        lastUpdatedPosition = position
    }
}

final class TestReceptacle: Receptacle {
    let handledEvents: [String]
    var receivedEvents: [String] = []

    init(handledEvents: [String]) {
        self.handledEvents = handledEvents
    }

    func receive(_ event: Event) {
        receivedEvents.append(event.name)
    }
}

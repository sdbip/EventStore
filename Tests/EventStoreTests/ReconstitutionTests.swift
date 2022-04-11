import XCTest
import EventStore

final class ReconstitutionTests: XCTestCase {
    func test_appliesEvents() throws {
        let history = History(
            type: "TestEntity",
            events: [PublishedEvent(name: "test")],
            version: 3
        )

        let entity: TestEntity = try history.reconstitute()

        XCTAssertNotNil(entity)
        XCTAssertEqual(entity.lastReconstitutedEvent?.name, "test")
    }

    func test_setsVersion() throws {
        let history = History(
            type: "TestEntity",
            events: [PublishedEvent(name: "test")],
            version: 3
        )

        let entity: TestEntity = try history.reconstitute()

        XCTAssertNotNil(entity)
        XCTAssertEqual(entity.version, 3)
    }

    func test_failsIfWrongType() throws {
        let history = History(
            type: "NotTestEntity",
            events: [PublishedEvent(name: "test")],
            version: 3
        )

        XCTAssertThrowsError(try history.reconstitute() as TestEntity)
    }
}

final class TestEntity: Entity {
    static let type = "TestEntity"
    let version: Int32
    var lastReconstitutedEvent: PublishedEvent?

    init(version: Int32) { self.version = version }

    func apply(_ event: PublishedEvent) {
        lastReconstitutedEvent = event
    }
}
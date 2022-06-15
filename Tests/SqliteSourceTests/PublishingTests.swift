import XCTest

import Source
import SQLite

private let testDBFile = "test.db"

final class PublishingTests: XCTestCase {
    var publisher: EventPublisher!
    var entityStore: EntityStore!
    var database: Database!

    override func setUp() {
        _ = try? FileManager.default.removeItem(atPath: testDBFile)

        do {
            database = try Database(openFile: testDBFile)
            publisher = EventPublisher(repository: database)
            entityStore = EntityStore(repository: database)

            try Schema.add(to: testDBFile)
        } catch {
            XCTFail("\(error)")
        }
    }

    override func tearDown() {
        _ = try? FileManager.default.removeItem(atPath: testDBFile)
    }

    func test_canPublishEntityWithoutEvents() throws {
        let entity = TestEntity.new(id: "test")
        entity.unpublishedEvents = []

        let history = try history(afterPublishingChangesFor: entity, actor: "user_x")

        XCTAssertEqual(history?.type, TestEntity.typeId)
        XCTAssertEqual(history?.id, "test")
        XCTAssertEqual(history?.version, 0)
    }

    func test_canPublishSingleEvent() throws {
        let entity = TestEntity.new(id: "test")
        entity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

        let history = try history(afterPublishingChangesFor: entity, actor: "user_x")
        let event = history?.events.first

        XCTAssertEqual(event?.name, "AnEvent")
        XCTAssertEqual(event?.jsonDetails, "{}")
        XCTAssertEqual(event?.actor, "user_x")
    }

    func test_versionMatchesNumberOfEvents() throws {
        let entity = TestEntity.new(id: "test")
        entity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

        let history = try history(afterPublishingChangesFor: entity, actor: "user_x")

        XCTAssertEqual(history?.version, 1)
    }

    func test_canPublishMultipleEvents() throws {
        let entity = TestEntity.new(id: "test")
        entity.unpublishedEvents = [
            UnpublishedEvent(name: "AnEvent", details: "{}")!,
            UnpublishedEvent(name: "AnEvent", details: "{}")!,
            UnpublishedEvent(name: "AnEvent", details: "{}")!
        ]

        let history = try history(afterPublishingChangesFor: entity, actor: "any")

        XCTAssertEqual(history?.events.count, 3)
        XCTAssertEqual(history?.version, 3)
    }

    func test_addsEventsExistingEntity() throws {
        let existingEntity = TestEntity.new(id: "test")
        try publisher.publishChanges(entity: existingEntity, actor: "any")

        let reconstitutedVersion = TestEntity(id: "test", version: 0, publishedEvents: [])
        reconstitutedVersion.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

        let history = try history(afterPublishingChangesFor: reconstitutedVersion, actor: "any")

        XCTAssertEqual(history?.events.count, 1)
    }

    func test_throwsIfVersionHasChanged() throws {
        let existingEntity = TestEntity.new(id: "test")
        existingEntity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]
        try publisher.publishChanges(entity: existingEntity, actor: "any")

        let reconstitutedVersion = TestEntity(id: "test", version: .eventCount(0), publishedEvents: [])
        reconstitutedVersion.unpublishedEvents.append(UnpublishedEvent(name: "AnEvent", details: "{}")!)

        XCTAssertThrowsError(try publisher.publishChanges(entity: reconstitutedVersion, actor: "user_x"))
    }

    func test_updatesNextPosition() throws {
        let existingEntity = TestEntity.new(id: "test")
        existingEntity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]
        try publisher.publishChanges(entity: existingEntity, actor: "any")

        let entity = TestEntity(id: "test", version: 1, publishedEvents: [])
        entity.unpublishedEvents = [
            UnpublishedEvent(name: "AnEvent", details: "{}")!,
            UnpublishedEvent(name: "AnEvent", details: "{}")!,
            UnpublishedEvent(name: "AnEvent", details: "{}")!
        ]

        try publisher.publishChanges(entity: entity, actor: "user_x")

        XCTAssertEqual(try database.nextPosition(), 4)
        XCTAssertEqual(try maxPositionOfEvents(forEntityWithId: "test"), 3)
    }

    private func history<EntityType: Entity>(afterPublishingChangesFor entity: EntityType, actor: String) throws -> History? {
        try publisher.publishChanges(entity: entity, actor: actor)
        return try entityStore.history(forEntityWithId: entity.id)
    }

    private func maxPositionOfEvents(forEntityWithId id: String) throws -> Int64? {
        return try database.operation(
            "SELECT MAX(position) FROM Events WHERE entityId = 'test'"
        ).single { $0.int64(at: 0) }
    }
}

final class TestEntity: Entity {
    static let typeId = "TestEntity"

    let id: String
    let version: EntityVersion
    var unpublishedEvents: [UnpublishedEvent] = []

    init(id: String, version: EntityVersion, publishedEvents events: [PublishedEvent]) {
        self.id = id
        self.version = version
    }
}

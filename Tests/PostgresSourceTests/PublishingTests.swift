import PostgresClientKit
import XCTest

import Postgres
import Source

final class PublishingTests: XCTestCase {
    var publisher: EventPublisher!
    var entityStore: EntityStore!
    var database: Database!

    override func setUp() async throws {
        database = try setUpEmptyTestDatabase()
        publisher = EventPublisher(repository: database)
        entityStore = EntityStore(repository: database)
    }

    func test_canPublishEntityWithoutEvents() throws {
        let entity = TestEntity(reconstitution: .init(id: "test"))
        entity.unpublishedEvents = []

        let history = try history(afterPublishingChangesFor: entity, actor: "user_x")

        XCTAssertEqual(history?.type, TestEntity.typeId)
        XCTAssertEqual(history?.id, "test")
        XCTAssertEqual(history?.version, 0)
    }

    func test_canPublishSingleEvent() throws {
        let entity = TestEntity(reconstitution: .init(id: "test"))
        entity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

        let history = try history(afterPublishingChangesFor: entity, actor: "user_x")
        let event = history?.events.first

        XCTAssertEqual(event?.name, "AnEvent")
        XCTAssertEqual(event?.jsonDetails, "{}")
        XCTAssertEqual(event?.actor, "user_x")
    }

    func test_versionMatchesNumberOfEvents() throws {
        let entity = TestEntity(reconstitution: .init(id: "test"))
        entity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

        let history = try history(afterPublishingChangesFor: entity, actor: "user_x")

        XCTAssertEqual(history?.version, 1)
    }

    func test_canPublishMultipleEvents() throws {
        let entity = TestEntity(reconstitution: .init(id: "test"))
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
        let existingEntity = TestEntity(reconstitution: .init(id: "test"))
        try publisher.publishChanges(to: existingEntity, actor: "any")

        let reconstitutedVersion = TestEntity(reconstitution: .init(id: "test", version: 0))
        reconstitutedVersion.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

        let history = try history(afterPublishingChangesFor: reconstitutedVersion, actor: "any")

        XCTAssertEqual(history?.events.count, 1)
    }

    func test_throwsIfVersionHasChanged() throws {
        let existingEntity = TestEntity(reconstitution: .init(id: "test"))
        existingEntity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]
        try publisher.publishChanges(to: existingEntity, actor: "any")

        let reconstitutedVersion = TestEntity(reconstitution: .init(id: "test", version: 0))
        reconstitutedVersion.unpublishedEvents.append(UnpublishedEvent(name: "AnEvent", details: "{}")!)

        XCTAssertThrowsError(try publisher.publishChanges(to: reconstitutedVersion, actor: "user_x"))
    }

    func test_updatesNextPosition() throws {
        let existingEntity = TestEntity(reconstitution: .init(id: "test"))
        existingEntity.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]
        try publisher.publishChanges(to: existingEntity, actor: "any")

        let entity = TestEntity(reconstitution: .init(id: "test", version: 1))
        entity.unpublishedEvents = [
            UnpublishedEvent(name: "AnEvent", details: "{}")!,
            UnpublishedEvent(name: "AnEvent", details: "{}")!,
            UnpublishedEvent(name: "AnEvent", details: "{}")!
        ]

        try publisher.publishChanges(to: entity, actor: "user_x")

        XCTAssertEqual(try database.nextPosition(), 4)
        XCTAssertEqual(try maxPositionOfEvents(forEntityWithId: "test"), 3)
    }

    private func history<EntityType: Entity>(afterPublishingChangesFor entity: EntityType, actor: String) throws -> History? {
        try publisher.publishChanges(to: entity, actor: actor)
        return try entityStore.entityHistory(id: entity.id)
    }

    private func maxPositionOfEvents(forEntityWithId id: String) throws -> Int64? {
        return try database.operation(
            "SELECT MAX(position) FROM Events WHERE entity_id = '\(id)'"
        ).single { try Int64($0[0].int()) }
    }
}

final class TestEntity: Entity {
    static let typeId = "TestEntity"

    var reconstitution: ReconstitutionData
    var unpublishedEvents: [UnpublishedEvent] = []

    init(reconstitution: ReconstitutionData) {
        self.reconstitution = reconstitution
    }

    func replay(_ event: PublishedEvent) {}}


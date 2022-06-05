import XCTest

import Postgres
import Source

extension XCTestCase {
    public func exposeError(_ block: () async throws -> Void, file: StaticString = #file, line: UInt = #line) async {
        do {
            try await block()
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }
}

final class PublishingTests: XCTestCase {
    var publisher: EventPublisher!
    var entityStore: EntityStore!
    var database: Database!

    override func setUp() async throws {
        database = try await setUpEmptyTestDatabase()
        publisher = EventPublisher(repository: database)
        entityStore = EntityStore(repository: database)
    }

    func test_canPublishEntityWithoutEvents() async {
        await exposeError {
            let entity = Entity(id: "test", state: TestEntity())
            entity.state.unpublishedEvents = []

            let history = try await history(afterPublishingChangesFor: entity, actor: "user_x")

            XCTAssertEqual(history?.type, TestEntity.typeId)
            XCTAssertEqual(history?.id, "test")
            XCTAssertEqual(history?.version, 0)
        }
    }

    func test_canPublishSingleEvent() async {
        await exposeError {
            let entity = Entity(id: "test", state: TestEntity())
            entity.state.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

            let history = try await history(afterPublishingChangesFor: entity, actor: "user_x")
            let event = history?.events.first

            XCTAssertEqual(event?.name, "AnEvent")
            XCTAssertEqual(event?.jsonDetails, "{}")
            XCTAssertEqual(event?.actor, "user_x")
        }
    }

    func test_versionMatchesNumberOfEvents() async {
        await exposeError {
            let entity = Entity(id: "test", state: TestEntity())
            entity.state.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

            let history = try await history(afterPublishingChangesFor: entity, actor: "user_x")

            XCTAssertEqual(history?.version, 1)
        }
    }

    func test_canPublishMultipleEvents() async {
        await exposeError {
            let entity = Entity(id: "test", state: TestEntity())
            entity.state.unpublishedEvents = [
                UnpublishedEvent(name: "AnEvent", details: "{}")!,
                UnpublishedEvent(name: "AnEvent", details: "{}")!,
                UnpublishedEvent(name: "AnEvent", details: "{}")!
            ]

            let history = try await history(afterPublishingChangesFor: entity, actor: "any")

            XCTAssertEqual(history?.events.count, 3)
            XCTAssertEqual(history?.version, 3)
        }
    }

    func test_addsEventsExistingEntity() async {
        await exposeError {
            let existingEntity = Entity(id: "test", state: TestEntity())
            try await publisher.publishChanges(entity: existingEntity, actor: "any")

            let reconstitutedVersion = Entity(id: "test", state: TestEntity(), version: 0)
            reconstitutedVersion.state.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]

            let history = try await history(afterPublishingChangesFor: reconstitutedVersion, actor: "any")

            XCTAssertEqual(history?.events.count, 1)
        }
    }

    func test_throwsIfVersionHasChanged() async {
        await exposeError {
            let existingEntity = Entity(id: "test", state: TestEntity())
            existingEntity.state.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]
            try await publisher.publishChanges(entity: existingEntity, actor: "any")

            let reconstitutedVersion = Entity(id: "test", state: TestEntity(), version: 0)
            reconstitutedVersion.state.unpublishedEvents.append(UnpublishedEvent(name: "AnEvent", details: "{}")!)

            await _XCTAssertThrowsError(try await publisher.publishChanges(entity: reconstitutedVersion, actor: "user_x"))
        }
    }

    func test_updatesNextPosition() async {
        await exposeError {
            let existingEntity = Entity(id: "test", state: TestEntity())
            existingEntity.state.unpublishedEvents = [UnpublishedEvent(name: "AnEvent", details: "{}")!]
            try await publisher.publishChanges(entity: existingEntity, actor: "any")

            let entity = Entity(id: "test", state: TestEntity(), version: 1)
            entity.state.unpublishedEvents = [
                UnpublishedEvent(name: "AnEvent", details: "{}")!,
                UnpublishedEvent(name: "AnEvent", details: "{}")!,
                UnpublishedEvent(name: "AnEvent", details: "{}")!
            ]

            try await publisher.publishChanges(entity: entity, actor: "user_x")

            let nextPosition = try await database.nextPosition()
            let maxPositionOfEvents = try await maxPositionOfEvents(forEntityWithId: "test")
            XCTAssertEqual(nextPosition, 4)
            XCTAssertEqual(maxPositionOfEvents, 3)
        }
    }

    private func history<__State>(afterPublishingChangesFor entity: Entity<__State>, actor: String) async throws -> History? where __State: EntityState {
        try await publisher.publishChanges(entity: entity, actor: actor)
        return try await entityStore.history(forEntityWithId: entity.id)
    }

    private func maxPositionOfEvents(forEntityWithId id: String) async throws -> Int64? {
        return try await database.single(
            #"SELECT MAX(position) FROM "Events" WHERE "entityId" = 'test'"#,
            as: Int64.self)
    }
}

final class TestEntity: EntityState {
    static let typeId = "TestEntity"

    var unpublishedEvents: [UnpublishedEvent] = []

    init() {}
    init(events: [PublishedEvent]) {}
}

func _XCTAssertThrowsError<T: Sendable>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

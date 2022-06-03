public final class EventSource {
    private let repository: EventRepository
    private let delegate: PositionDelegate?
    private var receptacles: [Receptacle] = []
    private var lastProjectedPosition: Int64?

    public init(repository: EventRepository, delegate: PositionDelegate? = nil) {
        self.repository = repository
        self.delegate = delegate
    }

    public func add(_ receptacle: Receptacle) {
        receptacles.append(receptacle)
    }

    public func projectEvents(count: Int) async throws {
        if lastProjectedPosition == nil {
            lastProjectedPosition = try delegate?.lastProjectedPosition()
        }

        let events = try await nextEvents(count: count)
        for event in events {
            for receptacle in receptacles.filter({ $0.handledEvents.contains(event.name) }) {
                receptacle.receive(event)
            }
            lastProjectedPosition = event.position
            try delegate?.update(position: event.position)
        }
    }

    private func nextEvents(count: Int) async throws -> [Event] {
        return try await repository.readEvents(maxCount: count, after: lastProjectedPosition)
    }
}

public protocol EventRepository {
    func readEvents(maxCount: Int, after position: Int64?) async throws -> [Event]
}

public protocol Receptacle {
    var handledEvents: [String] { get }
    func receive(_ event: Event)
}

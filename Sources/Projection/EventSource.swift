import Dispatch

private let queue = DispatchQueue(label: "EventSource")

/// The Source system that is being projected
public final class EventSource {
    private let repository: EventRepository
    private let delegate: PositionDelegate?
    private var receptacles: [Receptacle] = []
    private var lastProjectedPosition: Int64?

    /// Initializes an ``EventSource``.
    ///
    /// - Parameters:
    ///   - repository: The source database
    ///   - delegate: An object that can can be used to remember which
    ///   ``Event``s have already been processed, allowing projection to
    ///   continue instead of restarting  if the application shuts down.
    public init(repository: EventRepository, delegate: PositionDelegate? = nil) {
        self.repository = repository
        self.delegate = delegate
    }

    /// Add a recptacle of projected ``Event``s
    public func add(_ receptacle: Receptacle) {
        receptacles.append(receptacle)
    }

    /// Poll the source database for unprocessed ``Event``s, and notify the ``Receptacle``s if any are found.
    /// - Parameters:
    ///   - count: the maximum number of events to process.
    public func projectEvents(maxCount: Int) throws {
        try queue.sync {
            if lastProjectedPosition == nil {
                lastProjectedPosition = try delegate?.lastProjectedPosition()
            }

            let eventsByPosition = try nextEventsByPosition(maxCount: maxCount)
            for (position, events) in eventsByPosition {
                for event in events {
                    for receptacle in receptacles.filter({ $0.handledEvents.contains(event.name) }) {
                        receptacle.receive(event)
                    }
                }

                lastProjectedPosition = position
                try delegate?.update(position: position)
            }
        }
    }

    private func nextEvents(maxCount: Int) throws -> [Event] {
        return try repository.readEvents(maxCount: maxCount, after: lastProjectedPosition)
    }

    private func nextEventsByPosition(maxCount: Int) throws -> [(Int64, [Event])] {
        let oneTooMany = try repository.readEvents(maxCount: maxCount + 1, after: lastProjectedPosition)
        let events: [Event]
        if oneTooMany.count <= maxCount {
            events = oneTooMany
        } else if oneTooMany[maxCount].position == oneTooMany[maxCount - 1].position {
            events = oneTooMany.filter { $0.position != oneTooMany[maxCount].position }
        } else {
            events = oneTooMany.dropLast()
        }
        return Dictionary(grouping: events, by: { $0.position })
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
}

public protocol EventRepository {
    func readEvents(maxCount: Int, after position: Int64?) throws -> [Event]
}

/// A receptacle of projected events. This will be notified when new events are published.
public protocol Receptacle {
    /// Lists the ``name`` of events that this receptacle is interested in
    var handledEvents: [String] { get }
    /// Receives a projected ``Event``.
    ///
    /// Implement this to build your projection.
    func receive(_ event: Event)
}

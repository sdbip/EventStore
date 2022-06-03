import PostgresNIO

public struct Host {
    public var host: String
    public var port: Int
    public var database: String?
    public var useSSL: Bool

    public init(_ host: String, port: Int? = nil, database: String? = nil, useSSL: Bool = true) {
        self.host = host
        self.port = port ?? 5432
        self.database = database
        self.useSSL = useSSL
    }
}

public struct Credentials {
    public var username: String
    public var password: String?
    
    public init(username: String, password: String? = nil) {
        self.username = username
        self.password = password
    }
}

public final class Database {
    private let logger: Logger
    private let connection: PostgresConnection

    public init(connection: PostgresConnection, logger: Logger) {
        self.logger = logger
        self.connection = connection
    }

    deinit {
        let connection = self.connection
        Task { try await connection.close() }
    }
    
    public static func connect(on eventLoop: EventLoop, host: Host, credentials: Credentials) async throws -> Database {
        let config = PostgresConnection.Configuration(host: host, credentials: credentials)
        let logger = Logger(label: "postgres-logger")
        let connection = try await PostgresConnection.connect(
            on: eventLoop,
            configuration: config, id: 1, logger: logger)
        return Database(connection: connection, logger: logger)
    }

    public func execute(_ statement: PostgresQuery) async throws {
        try await connection.query(statement, logger: logger)
    }

    public func query<T1, T2, T3, T4, T5>(_ query: PostgresQuery, as type: (T1, T2, T3, T4, T5).Type) async throws -> [(T1, T2, T3, T4, T5)]
    where T1: PostgresDecodable, T2: PostgresDecodable, T3: PostgresDecodable, T4: PostgresDecodable, T5: PostgresDecodable {
        let rows = try await connection.query(query, logger: logger)
        var result: [(T1, T2, T3, T4, T5)] = []

        for try await row in rows {
            let item = try row.decode((T1, T2, T3, T4, T5).self, context: .default)
            result.append(item)
        }

        return result
    }

    public func single<T>(_ query: PostgresQuery, as type: T.Type) async throws -> T? where T: PostgresDecodable {
        let rows = try await connection.query(query, logger: logger)

        for try await row in rows {
            let item = try row.decode(type, context: .default)
            return item
        }

        return nil
    }

    public func single<T1, T2>(_ query: PostgresQuery, as type: (T1, T2).Type) async throws -> (T1, T2)?
    where T1: PostgresDecodable, T2: PostgresDecodable {
        let rows = try await connection.query(query, logger: logger)

        for try await row in rows {
            let item = try row.decode(type, context: .default)
            return item
        }

        return nil
    }
}

extension PostgresConnection.Configuration {
    init(host: Host, credentials: Credentials) {
        self.init(
            connection: .init(host: host.host, port: host.port),
            authentication: .init(username: credentials.username, database: host.database, password: credentials.password),
            tls: host.useSSL ? .prefer(try! .init(configuration: .clientDefault)) : .disable)
    }
}

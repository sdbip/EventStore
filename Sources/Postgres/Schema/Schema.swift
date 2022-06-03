import Foundation
import PostgresNIO

public enum Schema {
    public static func add(to database: Database) async throws {
        guard let schema = try bundledSchema() else { fatalError() }

        // PostgresNIO only supports executing one statement per request.
        // And it doesn't know to ignore empty requests.
        for sql in schema.split(separator: ";") {
            if String(sql).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            try await database.execute(PostgresQuery(unsafeSQL: String(sql)))
        }
    }

    private static func bundledSchema() throws -> String? {
        guard let schemaFile = Bundle.module.path(forResource: "schema", ofType: "sql") else { return nil }
        return try NSString(contentsOfFile: schemaFile, encoding: String.Encoding.utf8.rawValue) as String
    }
}

import SQLKit

struct DDLCommand: Command {
    func run() async throws {
        let dbManager = try await DatabaseManager()
        let database = dbManager.getDatabase()

        guard let sqlDb = database as? SQLDatabase else {
            throw CommandError.setupFailed("Database does not support raw SQL")
        }

        let rows = try await sqlDb.raw(
            """
            SELECT sql FROM sqlite_master
            WHERE type = 'table'
            AND name NOT LIKE '_fluent%'
            ORDER BY name
            """
        ).all()

        for row in rows {
            let sql = try row.decode(column: "sql", as: String.self)
            print("\(sql);")
            print()
        }

        try await dbManager.shutdown()
    }
}

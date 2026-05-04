import NavigatorDAL

struct ShowTemplateCommand: Command {
    let code: String

    func run() async throws {
        let dbManager = try await DatabaseManager()
        let database = dbManager.getDatabase()

        let service = TemplateService(database: database)
        let template = try await service.findLatestByCode(code)

        try await dbManager.shutdown()

        guard let template = template else {
            print("Template '\(code)' not found.")
            return
        }

        print("Code:           \(template.code ?? "")")
        print("Title:          \(template.title)")
        print("Description:    \(template.description)")
        print("Respondent:     \(template.respondentType.rawValue)")
        print("Version:        \(template.version)")
        print("")
        print(template.markdownContent)
    }
}

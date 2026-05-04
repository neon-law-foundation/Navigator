import NavigatorDAL

struct TemplatesListCommand: Command {
    func run() async throws {
        let dbManager = try await DatabaseManager(seed: true)
        let database = dbManager.getDatabase()

        let service = TemplateService(database: database)
        let templates = try await service.findAllLatest()

        try await dbManager.shutdown()

        if templates.isEmpty {
            print("No templates found.")
            return
        }

        let sorted = templates.sorted { ($0.code ?? "") < ($1.code ?? "") }
        let maxCodeLength = sorted.map { ($0.code ?? "").count }.max() ?? 4
        let codeWidth = max(maxCodeLength, 4)
        let maxTitleLength = sorted.map(\.title.count).max() ?? 5
        let titleWidth = max(maxTitleLength, 5)

        let codeHeader = "Code".padding(toLength: codeWidth, withPad: " ", startingAt: 0)
        let titleHeader = "Title".padding(toLength: titleWidth, withPad: " ", startingAt: 0)
        print("\(codeHeader)  \(titleHeader)  Respondent Type")
        print(
            String(repeating: "-", count: codeWidth)
                + "  "
                + String(repeating: "-", count: titleWidth)
                + "  "
                + String(repeating: "-", count: 14)
        )

        for template in sorted {
            let paddedCode = (template.code ?? "").padding(
                toLength: codeWidth,
                withPad: " ",
                startingAt: 0
            )
            let paddedTitle = template.title.padding(
                toLength: titleWidth,
                withPad: " ",
                startingAt: 0
            )
            print("\(paddedCode)  \(paddedTitle)  \(template.respondentType.rawValue)")
        }
    }
}

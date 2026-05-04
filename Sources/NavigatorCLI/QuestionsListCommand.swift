import NavigatorDAL

struct QuestionsListCommand: Command {
    func run() async throws {
        let dbManager = try await DatabaseManager(seed: true)
        let database = dbManager.getDatabase()

        let repo = QuestionRepository(database: database)
        let questions = try await repo.findAll().sorted { $0.code < $1.code }

        try await dbManager.shutdown()

        if questions.isEmpty {
            print("No questions found.")
            return
        }

        let maxCodeLength = questions.map(\.code.count).max() ?? 4
        let codeWidth = max(maxCodeLength, 4)

        let header = "Code".padding(toLength: codeWidth, withPad: " ", startingAt: 0)
        print("\(header)  Prompt")
        print(String(repeating: "-", count: codeWidth) + "  " + String(repeating: "-", count: 60))

        for question in questions {
            let paddedCode = question.code.padding(toLength: codeWidth, withPad: " ", startingAt: 0)
            print("\(paddedCode)  \(question.prompt)")
        }
    }
}

import Foundation
import NavigatorDAL

/// Creates a notation interactively from a template file.
///
/// Walks the template's questionnaire state machine, prompts for each question,
/// upserts answers, interpolates the template content, and creates the notation.
struct NotationCommand: Command {
    let templatePath: String
    let personID: UUID
    let entityID: UUID?

    func run() async throws {
        // Resolve the template code: if arg looks like a file path, derive the code
        // from it using the same convention as the seed loader (join path components
        // below any "Examples" directory with "__", lowercase). Otherwise treat the
        // argument as a code directly.
        let code: String
        if templatePath.hasSuffix(".md") || templatePath.contains("/") {
            let fileURL = URL(fileURLWithPath: templatePath).standardizedFileURL
            code = Self.codeFromFileURL(fileURL)
        } else {
            code = templatePath
        }

        let dbManager = try await DatabaseManager(seed: true)
        let database = dbManager.getDatabase()

        let templateService = TemplateService(database: database)
        guard let template = try await templateService.findLatestByCode(code) else {
            print("Error: Template '\(code)' not found in database.")
            print("List available templates with: navigator list templates")
            print("Import a custom template with: navigator import <directory>")
            try await dbManager.shutdown()
            exit(1)
        }

        let templateID = try template.requireID()
        let questionnaire = template.questionnaire.value
        let markdownContent = template.markdownContent

        // Resolve final person/entity IDs based on the template's respondent type.
        // Person templates default to person 1 (local dev identity).
        // Entity templates require --entity to be passed explicitly.
        let resolvedPersonID: UUID?
        let resolvedEntityID: UUID?
        switch template.respondentType {
        case .person:
            resolvedPersonID = personID
            resolvedEntityID = nil
        case .entity:
            resolvedPersonID = nil
            resolvedEntityID = entityID
            if resolvedEntityID == nil {
                print("Error: Template '\(code)' requires an entity. Pass --entity <id>.")
                print("Use `navigator list templates` and `navigator show template <code>` to discover seeded data.")
                try await dbManager.shutdown()
                exit(1)
            }
        case .personAndEntity:
            resolvedPersonID = personID
            resolvedEntityID = entityID
            if resolvedEntityID == nil {
                print("Error: Template '\(code)' requires both a person and entity. Pass --entity <id>.")
                try await dbManager.shutdown()
                exit(1)
            }
        }

        var currentState = "BEGIN"
        var collectedAnswers: [String: UUID] = [:]
        var answerValues: [String: String] = [:]

        let answerRepo = AnswerRepository()
        let questionRepo = QuestionRepository(database: database)

        while true {
            guard let transitions = questionnaire[currentState] else { break }
            guard let nextState = transitions["_"] else { break }
            if nextState == "END" { break }

            currentState = nextState

            let question = try await questionRepo.findByCode(currentState)
            if let question = question {
                let questionID = try question.requireID()

                print(question.prompt)
                if let helpText = question.helpText, !helpText.isEmpty {
                    print("  (\(helpText))")
                }
                print("> ", terminator: "")
                let value = readLine() ?? ""

                let answer = try await answerRepo.findOrCreate(
                    questionID: questionID,
                    personID: resolvedPersonID ?? personID,
                    entityID: resolvedEntityID,
                    value: value,
                    on: database
                )
                let answerID = try answer.requireID()
                collectedAnswers[currentState] = answerID
                answerValues[currentState] = value
            }
        }

        var rendered = markdownContent
        for (questionCode, value) in answerValues {
            rendered = rendered.replacingOccurrences(of: "{{\(questionCode)}}", with: value)
        }

        let notationService = NotationService(database: database)
        do {
            let notation = try await notationService.createNotation(
                templateID: templateID,
                personID: resolvedPersonID,
                entityID: resolvedEntityID,
                answers: collectedAnswers,
                renderedContent: rendered.isEmpty ? nil : rendered
            )
            let notationID = try notation.requireID()
            let finalState = notation.stateHistory.value.last?.toState ?? "BEGIN"
            print("Created notation #\(notationID) — state: \(finalState)")
        } catch {
            try await dbManager.shutdown()
            throw error
        }

        try await dbManager.shutdown()
    }

    /// Derives a template code from a file URL.
    ///
    /// Replicates the seed loader convention: finds the first `Examples` path
    /// component and joins every component below it (excluding the `.md` extension)
    /// with `__`, lowercased.  For example:
    /// `Sources/NavigatorDAL/Examples/Trusts/nevada.md` → `trusts__nevada`.
    ///
    /// Falls back to the filename stem when no `Examples` component is found.
    static func codeFromFileURL(_ url: URL) -> String {
        var components = url.pathComponents
        // Drop the file extension from the last component
        if let last = components.last {
            components[components.count - 1] = (last as NSString).deletingPathExtension
        }
        // Find the "Examples" directory and take everything below it
        if let examplesIndex = components.firstIndex(of: "Examples"),
            examplesIndex + 1 < components.count
        {
            return components[(examplesIndex + 1)...].joined(separator: "__").lowercased()
        }
        // Fallback: just the filename stem
        return components.last?.lowercased() ?? url.deletingPathExtension().lastPathComponent
    }
}

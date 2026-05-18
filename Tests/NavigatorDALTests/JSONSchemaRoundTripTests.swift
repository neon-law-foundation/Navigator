import Foundation
import NavigatorDAL
import Testing

/// Asserts that each bundled JSON Schema document agrees with its Swift
/// counterpart on the wire format. For each `JSONSchema.Name`:
///   1. The schema's `examples[0]` decodes into the Swift type without error.
///   2. A Swift fixture round-trips through JSON and back to itself.
///   3. The Swift fixture's encoded JSON has all of the schema's `required`
///      properties at the top level.
///
/// Schema-vs-type drift is caught here before it reaches a downstream consumer
/// reading the schema as documentation.
@Suite("JSON Schema round-trip")
struct JSONSchemaRoundTripTests {

    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    // MARK: - Schema accessors

    @Test("Every JSONSchema.Name resolves to a bundled schema document")
    func everyNameResolves() throws {
        for name in JSONSchema.Name.allCases {
            let json = try JSONSchema.schemaJSON(for: name)
            #expect(json["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
            #expect(json["title"] as? String == name.rawValue)
        }
    }

    // MARK: - Frontmatter

    @Test("Frontmatter schema example decodes")
    func frontmatterExampleDecodes() throws {
        let json = try firstExample(of: .frontmatter)
        let value = try decoder.decode(Frontmatter.self, from: json)
        #expect(value.title == "Nevada Trust")
        #expect(value.respondentType == .entity)
        #expect(value.code == "trusts__nevada")
    }

    @Test("Frontmatter Swift fixture matches schema required keys")
    func frontmatterRequiredKeys() throws {
        let fixture = Frontmatter(
            title: "X",
            respondentType: .person,
            code: "x",
            confidential: false,
            description: nil
        )
        try assertRequired(.frontmatter, encoded: fixture)
    }

    // MARK: - Questionnaire

    @Test("Questionnaire schema example decodes")
    func questionnaireExampleDecodes() throws {
        let json = try firstExample(of: .questionnaire)
        let value = try decoder.decode(Questionnaire.self, from: json)
        #expect(value.begin?[.unconditional] == StateName(rawValue: "person__trustee"))
    }

    @Test("Questionnaire Swift fixture round-trips through JSON")
    func questionnaireRoundTrip() throws {
        let fixture: Questionnaire = [
            "BEGIN": ["_": "person__trustee"],
            "person__trustee": ["_": "END"],
        ]
        let data = try encoder.encode(fixture)
        let again = try decoder.decode(Questionnaire.self, from: data)
        #expect(again == fixture)
    }

    // MARK: - Workflow

    @Test("Workflow schema example decodes")
    func workflowExampleDecodes() throws {
        let json = try firstExample(of: .workflow)
        let value = try decoder.decode(Workflow.self, from: json)
        let staffReview = StateName(rawValue: "staff_review")
        let notarization = StateName(rawValue: "notarization__for_trustee")
        #expect(value.transitions(from: staffReview)?[.unconditional] == notarization)
    }

    @Test("Workflow Swift fixture round-trips through JSON")
    func workflowRoundTrip() throws {
        let fixture: Workflow = [
            "BEGIN": ["_": "staff_review"],
            "staff_review": ["approved": "END", "_": "staff_review"],
        ]
        let data = try encoder.encode(fixture)
        let again = try decoder.decode(Workflow.self, from: data)
        #expect(again == fixture)
    }

    // MARK: - NotationEvent

    @Test("NotationEvent schema examples decode")
    func notationEventExamplesDecode() throws {
        let examples = try allExamples(of: .notationEvent)
        #expect(examples.count >= 1)
        for example in examples {
            let event = try decoder.decode(NotationEvent.self, from: example)
            #expect(!event.fromState.isEmpty)
            #expect(!event.toState.isEmpty)
        }
    }

    @Test("NotationEvent Swift fixture matches schema required keys")
    func notationEventRequiredKeys() throws {
        let fixture = NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: "staff_review",
            actor: .system,
            at: Date(timeIntervalSinceReferenceDate: 762_847_362.123)
        )
        try assertRequired(.notationEvent, encoded: fixture)
    }

    // MARK: - QuestionChoices

    @Test("QuestionChoices schema examples decode as [String: String]")
    func questionChoicesExamplesDecode() throws {
        let examples = try allExamples(of: .questionChoices)
        #expect(examples.count >= 1)
        for example in examples {
            let choices = try decoder.decode([String: String].self, from: example)
            #expect(!choices.isEmpty)
        }
    }

    @Test("QuestionChoices Swift fixture round-trips through JSON")
    func questionChoicesRoundTrip() throws {
        let fixture: [String: String] = [
            "approved": "Approved",
            "needs_revision": "Needs Revision",
        ]
        let data = try encoder.encode(fixture)
        let again = try decoder.decode([String: String].self, from: data)
        #expect(again == fixture)
    }

    // MARK: - Helpers

    private func firstExample(of name: JSONSchema.Name) throws -> Data {
        let examples = try allExamples(of: name)
        guard let first = examples.first else {
            Issue.record("Schema \(name.rawValue) is missing examples")
            return Data()
        }
        return first
    }

    private func allExamples(of name: JSONSchema.Name) throws -> [Data] {
        let json = try JSONSchema.schemaJSON(for: name)
        guard let examples = json["examples"] as? [Any] else {
            Issue.record("Schema \(name.rawValue) has no examples array")
            return []
        }
        return try examples.map { try JSONSerialization.data(withJSONObject: $0) }
    }

    private func assertRequired<Value: Encodable>(
        _ name: JSONSchema.Name,
        encoded value: Value
    ) throws {
        let schema = try JSONSchema.schemaJSON(for: name)
        guard let required = schema["required"] as? [String] else {
            Issue.record("Schema \(name.rawValue) is missing a required array")
            return
        }
        let data = try encoder.encode(value)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys = Set(parsed?.keys ?? [:].keys)
        for key in required {
            #expect(keys.contains(key), "\(name.rawValue) encoded payload missing required key '\(key)'")
        }
    }
}

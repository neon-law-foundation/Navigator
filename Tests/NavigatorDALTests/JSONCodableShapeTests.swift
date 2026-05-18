import Foundation
import NavigatorDAL
import Testing

/// Asserts that the typed payload structs (`Frontmatter`, `Questionnaire`,
/// `Workflow`) encode to and decode from the pre-typed on-disk JSON shape
/// without any restructuring. Protects against accidental Codable regressions
/// — Swift's defaults change subtly across releases when keyed dictionaries
/// are involved.
@Suite("Typed payload JSON wire shapes")
struct JSONCodableShapeTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    // MARK: - Frontmatter

    @Test("Frontmatter encodes with snake_case respondent_type")
    func frontmatterEncodesSnakeCase() throws {
        let value = Frontmatter(
            title: "Nevada Trust",
            respondentType: .entity,
            code: "trusts__nevada",
            confidential: false,
            description: "A basic Nevada trust."
        )
        let data = try encoder.encode(value)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"respondent_type\":\"entity\""))
        #expect(json.contains("\"title\":\"Nevada Trust\""))
        #expect(json.contains("\"code\":\"trusts__nevada\""))
        #expect(json.contains("\"confidential\":false"))
    }

    @Test("Frontmatter round-trips through the canonical JSON shape")
    func frontmatterRoundTrips() throws {
        let json = """
            {
                "title": "Nevada Trust",
                "respondent_type": "entity",
                "code": "trusts__nevada",
                "confidential": false,
                "description": "A basic Nevada trust."
            }
            """
        let value = try decoder.decode(Frontmatter.self, from: Data(json.utf8))
        #expect(value.title == "Nevada Trust")
        #expect(value.respondentType == .entity)
        #expect(value.code == "trusts__nevada")
        #expect(value.confidential == false)
        #expect(value.description == "A basic Nevada trust.")

        let re = try encoder.encode(value)
        let again = try decoder.decode(Frontmatter.self, from: re)
        #expect(again == value)
    }

    @Test("Frontmatter description is optional")
    func frontmatterOmittedDescription() throws {
        let json = """
            {
                "title": "X",
                "respondent_type": "person",
                "code": "x",
                "confidential": true
            }
            """
        let value = try decoder.decode(Frontmatter.self, from: Data(json.utf8))
        #expect(value.description == nil)
        #expect(value.confidential == true)
    }

    // MARK: - Questionnaire

    @Test("Questionnaire encodes as a state-of-condition-of-next-state map")
    func questionnaireShape() throws {
        let value: Questionnaire = [
            "BEGIN": ["_": "person__trustee"],
            "person__trustee": ["_": "END"],
        ]
        let data = try encoder.encode(value)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        let unwrapped = try #require(decoded)
        #expect(unwrapped["BEGIN"]?["_"] == "person__trustee")
        #expect(unwrapped["person__trustee"]?["_"] == "END")
    }

    @Test("Questionnaire decodes from raw on-disk shape")
    func questionnaireRoundTrips() throws {
        let json = """
            {
                "BEGIN": { "_": "person__trustee" },
                "person__trustee": { "_": "END" }
            }
            """
        let value = try decoder.decode(Questionnaire.self, from: Data(json.utf8))
        #expect(value.states.count == 2)
        #expect(value.begin?[.unconditional] == StateName(rawValue: "person__trustee"))
        #expect(
            value.transitions(from: StateName(rawValue: "person__trustee"))?[.unconditional] == .end
        )

        let re = try encoder.encode(value)
        let again = try decoder.decode(Questionnaire.self, from: re)
        #expect(again == value)
    }

    // MARK: - Workflow

    @Test("Workflow encodes the same shape as Questionnaire")
    func workflowShape() throws {
        let value: Workflow = [
            "BEGIN": ["_": "staff_review"],
            "staff_review": ["_": "notarization__for_trustee"],
            "notarization__for_trustee": ["yes": "END", "_": "staff_review"],
        ]
        let data = try encoder.encode(value)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        let unwrapped = try #require(decoded)
        #expect(unwrapped["BEGIN"]?["_"] == "staff_review")
        #expect(unwrapped["notarization__for_trustee"]?["yes"] == "END")
        #expect(unwrapped["notarization__for_trustee"]?["_"] == "staff_review")
    }

    @Test("Workflow step(at:) dispatches by state-name prefix")
    func workflowStepDispatch() throws {
        let value: Workflow = [
            "BEGIN": ["_": "staff_review"],
            "staff_review": ["_": "END"],
        ]
        let begin = try value.step(at: .begin)
        #expect(begin.actor == .system)
        #expect(begin is SystemStep)

        let staff = try value.step(at: StateName(rawValue: "staff_review"))
        #expect(staff.actor == .staff)
        #expect(staff is StaffReviewStep)
    }

    @Test("Workflow step(at:) throws for unknown states")
    func workflowStepUnknownState() throws {
        let value: Workflow = ["BEGIN": ["_": "END"]]
        #expect(throws: WorkflowError.self) {
            _ = try value.step(at: StateName(rawValue: "missing"))
        }
    }
}

import Foundation
import NavigatorDAL
import Testing

@Suite("Mailroom Workflow Steps")
struct MailroomWorkflowTests {

    // MARK: - WorkflowStep resolution

    @Test("mailroom_send prefix resolves to MailroomSendStep with staff actor")
    func testMailroomSendResolves() throws {
        let step = try resolveWorkflowStep(
            stateName: "mailroom_send__to_county",
            transitions: ["sent": "staff_review"]
        )
        #expect(step is MailroomSendStep)
        #expect(step.actor == .staff)
    }

    @Test("mailroom_receive prefix resolves to MailroomReceiveStep with staff actor")
    func testMailroomReceiveResolves() throws {
        let step = try resolveWorkflowStep(
            stateName: "mailroom_receive__from_county",
            transitions: ["received": "staff_review"]
        )
        #expect(step is MailroomReceiveStep)
        #expect(step.actor == .staff)
    }

    // MARK: - NotationEvent addressID

    @Test("NotationEvent encodes addressID when set")
    func testEventEncodesAddressID() throws {
        let addressID = UUID()
        let event = NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: "mailroom_send",
            actor: .system,
            at: Date(),
            addressID: addressID
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["addressID"] as? String == addressID.uuidString)
    }

    @Test("NotationEvent decodes addressID when present")
    func testEventDecodesAddressID() throws {
        let addressID = UUID()
        let json = """
            {
              "fromState": "BEGIN",
              "condition": "_",
              "toState": "mailroom_send",
              "actor": {"type": "system"},
              "at": "2024-01-01T00:00:00Z",
              "addressID": "\(addressID.uuidString)"
            }
            """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(NotationEvent.self, from: json)
        #expect(event.addressID == addressID)
    }

    @Test("NotationEvent decodes without addressID (backward compat)")
    func testEventDecodesWithoutAddressID() throws {
        let json = """
            {
              "fromState": "BEGIN",
              "condition": "_",
              "toState": "staff_review",
              "actor": {"type": "system"},
              "at": "2024-01-01T00:00:00Z"
            }
            """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(NotationEvent.self, from: json)
        #expect(event.addressID == nil)
    }

    // MARK: - NotationEvent documentURL

    @Test("NotationEvent encodes documentURL when set")
    func testEventEncodesDocumentURL() throws {
        let event = NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: "mailroom_send",
            actor: .system,
            at: Date(),
            documentURL: "https://example.com/doc.pdf"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["documentURL"] as? String == "https://example.com/doc.pdf")
    }

    @Test("NotationEvent decodes documentURL when present")
    func testEventDecodesDocumentURL() throws {
        let json = """
            {
              "fromState": "BEGIN",
              "condition": "_",
              "toState": "mailroom_send",
              "actor": {"type": "system"},
              "at": "2024-01-01T00:00:00Z",
              "documentURL": "https://example.com/doc.pdf"
            }
            """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(NotationEvent.self, from: json)
        #expect(event.documentURL == "https://example.com/doc.pdf")
    }

    @Test("NotationEvent decodes without documentURL (backward compat)")
    func testEventDecodesWithoutDocumentURL() throws {
        let json = """
            {
              "fromState": "BEGIN",
              "condition": "_",
              "toState": "staff_review",
              "actor": {"type": "system"},
              "at": "2024-01-01T00:00:00Z"
            }
            """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(NotationEvent.self, from: json)
        #expect(event.documentURL == nil)
    }

    // MARK: - Both fields nil by default

    @Test("NotationEvent has nil addressID and documentURL by default")
    func testEventDefaultsNil() throws {
        let event = NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: "staff_review",
            actor: .system,
            at: Date()
        )
        #expect(event.addressID == nil)
        #expect(event.documentURL == nil)
    }
}

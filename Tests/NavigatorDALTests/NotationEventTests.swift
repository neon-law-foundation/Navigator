import Foundation
import NavigatorDAL
import Testing

private let personFortyTwo = UUID()
private let entitySeven = UUID()
private let entityTwo = UUID()
private let personFive = UUID()
private let personNinetyNine = UUID()
private let entityThree = UUID()

@Suite("NotationActor")
struct NotationActorTests {

    @Test("person encodes to {type: person, id: <uuid>}")
    func testPersonEncoding() throws {
        let actor = NotationActor.person(id: personFortyTwo)
        let data = try JSONEncoder().encode(actor)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "person")
        #expect(json?["id"] as? String == personFortyTwo.uuidString)
    }

    @Test("entity encodes to {type: entity, id: <uuid>}")
    func testEntityEncoding() throws {
        let actor = NotationActor.entity(id: entitySeven)
        let data = try JSONEncoder().encode(actor)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "entity")
        #expect(json?["id"] as? String == entitySeven.uuidString)
    }

    @Test("system encodes to {type: system}")
    func testSystemEncoding() throws {
        let actor = NotationActor.system
        let data = try JSONEncoder().encode(actor)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "system")
        #expect(json?["id"] == nil)
    }

    @Test("person round-trips through JSON")
    func testPersonRoundTrip() throws {
        let original = NotationActor.person(id: personNinetyNine)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotationActor.self, from: data)
        #expect(decoded == original)
    }

    @Test("entity round-trips through JSON")
    func testEntityRoundTrip() throws {
        let original = NotationActor.entity(id: entityThree)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotationActor.self, from: data)
        #expect(decoded == original)
    }

    @Test("system round-trips through JSON")
    func testSystemRoundTrip() throws {
        let original = NotationActor.system
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotationActor.self, from: data)
        #expect(decoded == original)
    }

    @Test("unknown type throws decoding error")
    func testUnknownTypeThrows() {
        let json = #"{"type":"robot"}"#.data(using: .utf8)!
        #expect(throws: Error.self) {
            try JSONDecoder().decode(NotationActor.self, from: json)
        }
    }
}

@Suite("NotationEvent")
struct NotationEventTests {

    @Test("NotationEvent round-trips through JSON")
    func testRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let event = NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: "staff_review",
            actor: .system,
            at: date,
            note: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NotationEvent.self, from: data)
        #expect(decoded.fromState == event.fromState)
        #expect(decoded.condition == event.condition)
        #expect(decoded.toState == event.toState)
        #expect(decoded.actor == event.actor)
        #expect(decoded.note == event.note)
    }

    @Test("NotationEvent with note round-trips through JSON")
    func testRoundTripWithNote() throws {
        let event = NotationEvent(
            fromState: "review",
            condition: "approved",
            toState: "END",
            actor: .person(id: personFive),
            at: Date(),
            note: "Looks good"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NotationEvent.self, from: data)
        #expect(decoded.note == "Looks good")
        #expect(decoded.actor == .person(id: personFive))
    }

    @Test("Array of NotationEvents round-trips through JSON")
    func testArrayRoundTrip() throws {
        let events = [
            NotationEvent(
                fromState: "BEGIN",
                condition: "_",
                toState: "open",
                actor: .system,
                at: Date()
            ),
            NotationEvent(
                fromState: "open",
                condition: "submit",
                toState: "review",
                actor: .entity(id: entityTwo),
                at: Date()
            ),
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(events)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([NotationEvent].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].fromState == "BEGIN")
        #expect(decoded[1].actor == .entity(id: entityTwo))
    }
}

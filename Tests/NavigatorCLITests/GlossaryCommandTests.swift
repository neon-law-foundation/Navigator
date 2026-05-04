import Testing

@testable import NavigatorCLI

@Suite("Glossary Command")
struct GlossaryCommandTests {

    @Test("Glossary command runs without error when no term given")
    func testGlossaryAll() async throws {
        let cmd = GlossaryCommand(term: nil)
        try await cmd.run()
    }

    @Test("Glossary command looks up a known term")
    func testGlossarySingleTerm() async throws {
        let cmd = GlossaryCommand(term: "Notation")
        try await cmd.run()
    }

    @Test("Glossary command is case-insensitive")
    func testGlossaryCaseInsensitive() async throws {
        let cmd = GlossaryCommand(term: "notation")
        try await cmd.run()
    }

    @Test("Glossary command throws on unknown term")
    func testGlossaryUnknownTerm() async throws {
        let cmd = GlossaryCommand(term: "Bogus")
        await #expect(throws: CommandError.self) {
            try await cmd.run()
        }
    }
}

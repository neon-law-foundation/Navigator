import Testing

@testable import NavigatorWeb

@Suite("SortSpec")
struct SortSpecTests {
    @Test("parse returns an empty spec for nil and empty input")
    func parseEmpty() {
        #expect(SortSpec.parse(nil) == SortSpec())
        #expect(SortSpec.parse("") == SortSpec())
    }

    @Test("parse reads ascending and descending fields")
    func parseSingleFields() {
        #expect(
            SortSpec.parse("name") == .single("name", .ascending)
        )
        #expect(
            SortSpec.parse("-name") == .single("name", .descending)
        )
    }

    @Test("parse splits comma-separated multi-field sorts in order")
    func parseMultiField() {
        let spec = SortSpec.parse("-receivedAt,sender")
        #expect(spec.fields.count == 2)
        #expect(spec.fields[0] == SortSpec.Field(key: "receivedAt", direction: .descending))
        #expect(spec.fields[1] == SortSpec.Field(key: "sender", direction: .ascending))
    }

    @Test("parse drops empty fragments produced by stray commas or whitespace")
    func parseDropsEmpty() {
        let spec = SortSpec.parse(",,sender, ,")
        #expect(spec.fields == [SortSpec.Field(key: "sender", direction: .ascending)])
    }

    @Test("parse drops a lone minus sign with no key after it")
    func parseDropsLoneMinus() {
        let spec = SortSpec.parse("-,name")
        #expect(spec.fields == [SortSpec.Field(key: "name", direction: .ascending)])
    }

    @Test("encoded round-trips through parse for an empty spec")
    func encodedEmpty() {
        #expect(SortSpec().encoded == "")
    }

    @Test("encoded prefixes descending fields with a minus")
    func encodedSingle() {
        #expect(SortSpec.single("name", .ascending).encoded == "name")
        #expect(SortSpec.single("name", .descending).encoded == "-name")
    }

    @Test("encoded joins multi-field specs with a comma")
    func encodedMultiField() {
        let spec = SortSpec(fields: [
            SortSpec.Field(key: "receivedAt", direction: .descending),
            SortSpec.Field(key: "sender", direction: .ascending),
        ])
        #expect(spec.encoded == "-receivedAt,sender")
    }

    @Test("parse then encode round-trips for a multi-field spec")
    func parseEncodeRoundTrip() {
        let raw = "-receivedAt,sender,-subject"
        #expect(SortSpec.parse(raw).encoded == raw)
    }

    @Test("direction(for:) returns the field's direction when present")
    func directionLookup() {
        let spec = SortSpec.single("name", .descending)
        #expect(spec.direction(for: "name") == .descending)
        #expect(spec.direction(for: "other") == nil)
    }

    @Test("toggling flips ascending to descending on the same key")
    func toggleFlipsAscending() {
        let spec = SortSpec.single("name", .ascending)
        #expect(spec.toggling("name") == .single("name", .descending))
    }

    @Test("toggling flips descending to ascending on the same key")
    func toggleFlipsDescending() {
        let spec = SortSpec.single("name", .descending)
        #expect(spec.toggling("name") == .single("name", .ascending))
    }

    @Test("toggling a fresh key starts ascending and drops the previous sort")
    func toggleSwitchesKey() {
        let spec = SortSpec.single("name", .descending)
        #expect(spec.toggling("age") == .single("age", .ascending))
    }

    @Test("validated returns the spec when every field is in the allowlist")
    func validatedAccepts() throws {
        let spec = SortSpec.parse("-receivedAt,sender")
        let allowed: Set<String> = ["receivedAt", "sender", "subject"]
        #expect(try spec.validated(against: allowed) == spec)
    }

    @Test("validated throws unsupportedField for the first unknown key")
    func validatedRejects() {
        let spec = SortSpec.parse("receivedAt,-mystery")
        let allowed: Set<String> = ["receivedAt", "sender"]
        #expect(throws: SortError.unsupportedField("mystery")) {
            try spec.validated(against: allowed)
        }
    }

    @Test("SortDirection.arrow renders distinct glyphs for the two directions")
    func arrowGlyphs() {
        #expect(SortDirection.ascending.arrow != SortDirection.descending.arrow)
        #expect(!SortDirection.ascending.arrow.isEmpty)
        #expect(!SortDirection.descending.arrow.isEmpty)
    }
}

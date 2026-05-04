import Foundation

struct GlossaryCommand: Command {
    let term: String?

    private static let terms: [(name: String, definition: String)] = [
        (
            "Template",
            "A versioned YAML document definition with frontmatter metadata and a body."
        ),
        (
            "Notation",
            "A filled-in instance of a Template for a specific respondent."
        ),
        (
            "RespondentType",
            "Whether the subject of a Notation is a `person` or an `entity`."
        ),
        (
            "Frontmatter",
            "The YAML block at the top of a Template (between `---` delimiters)."
        ),
        (
            "Code",
            "The unique string identifier for a Template (e.g. `NDA-001`). Stable across versions."
        ),
        (
            "Version",
            "A semantic version string (`MAJOR.MINOR.PATCH`)."
        ),
        (
            "State Machine",
            "Notation lifecycle: open → review → waitingForQuestionnaire → waitingForWorkflow → closed."
        ),
        (
            "Questionnaire",
            "Structured questions presented to the respondent to gather facts for the Notation."
        ),
        (
            "Workflow",
            "Automated tasks triggered after a Questionnaire is complete (e.g. PDF generation, e-signature)."
        ),
        (
            "NotationState",
            "One of: `open`, `review`, `waitingForQuestionnaire`, `waitingForWorkflow`, `closed`."
        ),
        (
            "Person",
            "A natural person respondent (name, DOB, SSN/ITIN, address)."
        ),
        (
            "Entity",
            "A legal entity respondent (corporation, LLC, trust, etc.)."
        ),
        (
            "EntityType",
            "Classification of an Entity (e.g. `corporation`, `llc`, `trust`, `partnership`)."
        ),
        (
            "Jurisdiction",
            "Governing legal authority, expressed as an ISO 3166-2 code (e.g. `US-CA`)."
        ),
        (
            "User",
            "An authenticated system user (attorney, paralegal, or admin)."
        ),
        (
            "Project",
            "A grouping of related Notations under a common matter or client engagement."
        ),
        (
            "Question",
            "A single prompt within a Questionnaire, with a type and optional validation rules."
        ),
        (
            "GitRepository",
            "A version-controlled repository linked to a Project."
        ),
        (
            "Credential",
            "Stored authentication for an external system (e.g. court filing portal, e-signature provider)."
        ),
        (
            "Mailbox",
            "Email inbox for a Project or User; receives filings, notices, and correspondence."
        ),
        (
            "Disclosure",
            "A mandatory notice required by law, tracked for compliance."
        ),
        (
            "PersonEntityRole",
            "The role a Person plays within an Entity (e.g. `officer`, `director`, `member`, `trustee`)."
        ),
        (
            "Document",
            "Any client-provided or generated file associated with a legal matter, owned by a Project."
        ),
        (
            "Letter",
            "A physical piece of mail managed by a Mailroom, optionally linked to a scanned Blob."
        ),
        (
            "ShareIssuance",
            "Records the issuance of shares in an Entity to a polymorphic shareholder (Person or Entity)."
        ),
    ]

    func run() async throws {
        if let term = term {
            guard
                let entry = Self.terms.first(where: {
                    $0.name.lowercased() == term.lowercased()
                })
            else {
                print("Unknown term: '\(term)'")
                print("Run `navigator glossary` to list all terms.")
                throw CommandError.missingArgument(term)
            }
            print("\(entry.name) — \(entry.definition)")
        } else {
            for entry in Self.terms {
                print("\(entry.name) — \(entry.definition)")
            }
        }
    }
}

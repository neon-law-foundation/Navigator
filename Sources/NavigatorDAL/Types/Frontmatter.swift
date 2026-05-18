import Foundation

/// Structured metadata parsed from a template's YAML frontmatter block.
///
/// `Frontmatter` is the canonical in-memory shape for everything the YAML
/// frontmatter of a markdown template carries — apart from the questionnaire
/// and workflow state machines, which are persisted on their own columns.
///
/// On disk it is serialised as a JSONB document via
/// ``JSONStored`` on ``Template/frontmatter``. The ``Template`` model also
/// keeps `title`, `code`, `respondentType`, and `description` as first-class
/// columns; those values are denormalised from the same `Frontmatter` instance
/// by ``TemplateService/createVersion(gitRepositoryID:version:frontmatter:markdownContent:questionnaire:workflow:ownerID:)``.
///
/// All required fields are non-optional, so a `Frontmatter` value is by
/// construction a valid template header.
public struct Frontmatter: Codable, Sendable, Equatable {
    public var title: String
    public var respondentType: RespondentType
    public var code: String
    public var confidential: Bool
    public var description: String?

    public init(
        title: String,
        respondentType: RespondentType,
        code: String,
        confidential: Bool,
        description: String?
    ) {
        self.title = title
        self.respondentType = respondentType
        self.code = code
        self.confidential = confidential
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case respondentType = "respondent_type"
        case code
        case confidential
        case description
    }
}

extension Frontmatter {
    /// Sentinel value used solely by Fluent's no-arg ``Template/init()`` so the
    /// model can be decoded before its fields are filled in. Callers must not
    /// persist a `Template` whose `frontmatter.value` is still `.placeholder` —
    /// `TemplateService.createVersion` overwrites it as the first step.
    public static let placeholder = Frontmatter(
        title: "",
        respondentType: .person,
        code: "",
        confidential: false,
        description: nil
    )
}

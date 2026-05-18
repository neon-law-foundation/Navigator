import FluentKit
import Foundation

/// Defines who can be assigned a template.
///
/// Templates can target individuals, organizations, or both depending on the requirement.
public enum RespondentType: String, Codable, CaseIterable, Sendable {
    /// Template assigned to an individual person.
    case person = "person"

    /// Template assigned to a legal entity or organization.
    case entity = "entity"

    /// Template assigned to both a person and entity together.
    case personAndEntity = "person_and_entity"
}

/// A versioned document definition that can be assigned to people or entities as a ``Notation``.
///
/// Templates are markdown documents with YAML frontmatter, stored in git repositories.
/// Each record represents one version of a template at a specific git commit SHA.
/// Multiple versions of the same template coexist in the database, identified by ``code``.
///
/// ## Relationship to Notation
///
/// A `Template` is the reusable definition — the what. A ``Notation`` is a formal
/// record that a specific respondent has been assigned a template — the who and when.
///
/// ## Topics
///
/// ### Creating Templates
///
/// - ``init()``
/// - ``setDefaultOwner(on:)``
///
/// ### Properties
///
/// - ``id``
/// - ``title``
/// - ``description``
/// - ``respondentType``
/// - ``markdownContent``
/// - ``frontmatter``
/// - ``version``
/// - ``code``
/// - ``gitRepository``
/// - ``owner``
/// - ``questionnaire``
/// - ``workflow``
/// - ``insertedAt``
/// - ``updatedAt``
public final class Template: Model, @unchecked Sendable {
    public static let schema = "templates"

    /// The unique identifier for this template version.
    @ID(key: .id)
    public var id: UUID?

    /// The display title of the template.
    @Field(key: "title")
    public var title: String

    /// A brief description of the template's purpose.
    @Field(key: "description")
    public var description: String

    /// Specifies who this template can be assigned to.
    ///
    /// See ``RespondentType`` for valid options.
    @Enum(key: "respondent_type")
    public var respondentType: RespondentType

    /// The full markdown content of the template.
    @Field(key: "markdown_content")
    public var markdownContent: String

    /// Structured metadata extracted from the template's frontmatter.
    ///
    /// Persisted as a JSONB document via ``JSONStored``; access the typed
    /// fields via `frontmatter.value`. The top-level Template columns
    /// (``title``, ``code``, ``respondentType``, ``description``) mirror the
    /// values in this struct as denormalised index columns; they are written
    /// from the same `Frontmatter` instance by
    /// ``TemplateService/createVersion(gitRepositoryID:version:frontmatter:markdownContent:questionnaire:workflow:ownerID:)``.
    @Field(key: "frontmatter")
    public var frontmatter: JSONStored<Frontmatter>

    /// The git commit SHA from the source repository.
    ///
    /// Tracks which version of the template from the git repository this record represents.
    /// Typically a 40-character SHA-1 hash (e.g., "abc123def456789012345678901234567890abcd").
    @Field(key: "version")
    public var version: String

    /// Unique code identifying this template type within its repository.
    ///
    /// The code remains constant across versions, linking all versions of the same template.
    /// For example, "france-contractor-agreement" identifies all versions of that template.
    @OptionalField(key: "code")
    public var code: String?

    /// The git repository where this template is stored.
    ///
    /// References the AWS CodeCommit repository containing the template source.
    @OptionalParent(key: "git_repository_id")
    public var gitRepository: GitRepository?

    /// The entity that owns or manages this template.
    @OptionalParent(key: "owner_id")
    public var owner: Entity?

    /// The questionnaire state machine for this template.
    ///
    /// Persisted as a JSONB document via ``JSONStored``; access via
    /// `questionnaire.value`. See ``Questionnaire`` for the typed surface.
    @Field(key: "questionnaire")
    public var questionnaire: JSONStored<Questionnaire>

    /// The workflow state machine for this template.
    ///
    /// Persisted as a JSONB document via ``JSONStored``; access via
    /// `workflow.value`. See ``Workflow`` for the typed surface — including
    /// ``Workflow/step(at:)`` which dispatches to a concrete ``WorkflowStep``.
    @Field(key: "workflow")
    public var workflow: JSONStored<Workflow>

    /// The timestamp when this template version was created.
    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    /// The timestamp when this template version was last updated.
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    /// Creates an empty template instance.
    ///
    /// Required by Fluent so rows can be decoded before fields are populated.
    /// All three JSONB columns are seeded with empty/placeholder values;
    /// production callers go through
    /// ``TemplateService/createVersion(gitRepositoryID:version:frontmatter:markdownContent:questionnaire:workflow:ownerID:)``
    /// which overwrites them before the row is saved.
    public init() {
        self.frontmatter = JSONStored(.placeholder)
        self.questionnaire = JSONStored(Questionnaire())
        self.workflow = JSONStored(Workflow())
    }

    /// Sets the owner to Neon Law Foundation.
    ///
    /// Looks up the Neon Law Foundation entity and assigns it as this template's owner.
    ///
    /// - Parameter database: The database connection to use for the lookup.
    /// - Throws: `TemplateError.missingRequiredField` if Neon Law Foundation entity is not found.
    public func setDefaultOwner(on database: Database) async throws {
        let neonLawFoundation = try await Entity.query(on: database)
            .filter(\.$name == "Neon Law Foundation")
            .first()

        guard let neonLawFoundation = neonLawFoundation else {
            throw TemplateError.missingRequiredField("Neon Law Foundation entity")
        }

        self.$owner.id = try neonLawFoundation.requireID()
    }
}

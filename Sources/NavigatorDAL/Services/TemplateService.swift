import FluentKit
import Foundation

/// Service responsible for template version management and validation.
public actor TemplateService {
    private let database: Database
    private let validator = TemplateValidator()

    public init(database: Database) {
        self.database = database
    }

    /// Finds the latest version of a template by code across all repositories.
    ///
    /// - Parameter code: The template code to look up.
    /// - Returns: The most recent template with that code, or `nil` if none exists.
    public func findLatestByCode(_ code: String) async throws -> Template? {
        let results = try await Template.query(on: database)
            .sort(\.$insertedAt, .descending)
            .all()

        return results.first { $0.code == code }
    }

    /// Finds the latest version of each unique template code across all repositories.
    ///
    /// Results are sorted by `insertedAt` descending, then deduplicated by `code`,
    /// so the most recent version of each template is returned.
    ///
    /// - Returns: An array of the latest template per unique code.
    public func findAllLatest() async throws -> [Template] {
        let all = try await Template.query(on: database)
            .sort(\.$insertedAt, .descending)
            .all()

        var seen = Set<String>()
        var result: [Template] = []
        for template in all {
            guard let code = template.code else { continue }
            if !seen.contains(code) {
                seen.insert(code)
                result.append(template)
            }
        }
        return result
    }

    /// Finds the latest version of a template by repository and code.
    ///
    /// - Parameters:
    ///   - gitRepositoryID: The ID of the git repository.
    ///   - code: The template code.
    /// - Returns: The most recent template version, or `nil` if none exists.
    public func findLatestVersion(
        gitRepositoryID: UUID,
        code: String
    ) async throws -> Template? {
        let results = try await Template.query(on: database)
            .filter(\.$gitRepository.$id == gitRepositoryID)
            .sort(\.$insertedAt, .descending)
            .all()

        return results.first { $0.code == code }
    }

    /// Finds all versions of a template ordered by most recent first.
    ///
    /// - Parameters:
    ///   - gitRepositoryID: The ID of the git repository.
    ///   - code: The template code.
    /// - Returns: An array of all versions of the template.
    public func findAllVersions(
        gitRepositoryID: UUID,
        code: String
    ) async throws -> [Template] {
        let results = try await Template.query(on: database)
            .filter(\.$gitRepository.$id == gitRepositoryID)
            .sort(\.$insertedAt, .descending)
            .all()

        return results.filter { $0.code == code }
    }

    /// Creates a new template version from a typed ``Frontmatter`` plus the
    /// questionnaire and workflow state machines.
    ///
    /// The first-class Template columns (`title`, `code`, `respondentType`,
    /// `description`) are denormalised from `frontmatter`. The full
    /// `Frontmatter` is also stored in the `frontmatter` JSONB column as the
    /// canonical source of truth.
    ///
    /// - Parameters:
    ///   - gitRepositoryID: The ID of the git repository.
    ///   - version: Git commit SHA.
    ///   - frontmatter: Typed YAML frontmatter for the template.
    ///   - markdownContent: The template content.
    ///   - questionnaire: The questionnaire state machine.
    ///   - workflow: The workflow state machine.
    ///   - ownerID: Optional owner entity ID.
    /// - Returns: The created template.
    /// - Throws: `TemplateError.validationFailed` when ``Frontmatter`` fails
    ///   structural checks; `TemplateError.versionAlreadyExists` or
    ///   `TemplateError.titleAlreadyExists` on conflicts with existing rows.
    public func createVersion(
        gitRepositoryID: UUID,
        version: String,
        frontmatter: Frontmatter,
        markdownContent: String,
        questionnaire: Questionnaire = Questionnaire(),
        workflow: Workflow = Workflow(),
        ownerID: UUID?
    ) async throws -> Template {
        let validations = validator.validate(frontmatter)
        if !validations.isEmpty {
            throw TemplateError.validationFailed(validations)
        }

        if !questionnaire.isEmpty {
            try questionnaire.validate()
        }
        if !workflow.isEmpty {
            try workflow.validate()
        }

        let allVersions = try await Template.query(on: database)
            .filter(\.$gitRepository.$id == gitRepositoryID)
            .filter(\.$version == version)
            .all()

        if allVersions.contains(where: { $0.code == frontmatter.code }) {
            throw TemplateError.versionAlreadyExists(
                repository: gitRepositoryID,
                code: frontmatter.code,
                version: version
            )
        }

        let existingWithTitle = try await Template.query(on: database)
            .filter(\.$gitRepository.$id == gitRepositoryID)
            .filter(\.$title == frontmatter.title)
            .first()

        if existingWithTitle != nil {
            throw TemplateError.titleAlreadyExists(frontmatter.title)
        }

        let template = Template()
        template.$gitRepository.id = gitRepositoryID
        template.version = version
        template.title = frontmatter.title
        template.code = frontmatter.code
        template.respondentType = frontmatter.respondentType
        template.description = frontmatter.description ?? ""
        template.markdownContent = markdownContent
        template.frontmatter = JSONStored(frontmatter)
        template.questionnaire = JSONStored(questionnaire)
        template.workflow = JSONStored(workflow)
        template.$owner.id = ownerID

        try await template.save(on: database)
        return template
    }
}

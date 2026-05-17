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

    /// Creates a new template version.
    ///
    /// - Parameters:
    ///   - gitRepositoryID: The ID of the git repository.
    ///   - code: Unique code for this template type.
    ///   - version: Git commit SHA.
    ///   - title: Display title.
    ///   - description: Brief description.
    ///   - respondentType: Who can be assigned this template.
    ///   - markdownContent: The template content.
    ///   - frontmatter: Structured metadata.
    ///   - questionnaire: The questionnaire state machine map.
    ///   - workflow: The workflow state machine map.
    ///   - ownerID: Optional owner entity ID.
    /// - Returns: The created template.
    /// - Throws: `TemplateError` if the version already exists.
    public func createVersion(
        gitRepositoryID: UUID,
        code: String,
        version: String,
        title: String,
        description: String,
        respondentType: RespondentType,
        markdownContent: String,
        frontmatter: [String: String],
        questionnaire: [String: [String: String]] = [:],
        workflow: [String: [String: String]] = [:],
        ownerID: UUID?
    ) async throws -> Template {
        let allVersions = try await Template.query(on: database)
            .filter(\.$gitRepository.$id == gitRepositoryID)
            .filter(\.$version == version)
            .all()

        if allVersions.contains(where: { $0.code == code }) {
            throw TemplateError.versionAlreadyExists(
                repository: gitRepositoryID,
                code: code,
                version: version
            )
        }

        let existingWithTitle = try await Template.query(on: database)
            .filter(\.$gitRepository.$id == gitRepositoryID)
            .filter(\.$title == title)
            .first()

        if existingWithTitle != nil {
            throw TemplateError.titleAlreadyExists(title)
        }

        let template = Template()
        template.$gitRepository.id = gitRepositoryID
        template.code = code
        template.version = version
        template.title = title
        template.description = description
        template.respondentType = respondentType
        template.markdownContent = markdownContent
        template.frontmatter = JSONStored(frontmatter)
        template.questionnaire = JSONStored(questionnaire)
        template.workflow = JSONStored(workflow)
        template.$owner.id = ownerID

        try await template.save(on: database)
        return template
    }

    /// Creates a new template version with validation.
    ///
    /// Validates all template fields before saving to the database.
    ///
    /// - Parameters:
    ///   - gitRepositoryID: The ID of the git repository.
    ///   - code: Unique code for this template type.
    ///   - version: Git commit SHA.
    ///   - title: Display title.
    ///   - description: Brief description.
    ///   - respondentType: Who can be assigned this template.
    ///   - markdownContent: The template content.
    ///   - frontmatter: Structured metadata.
    ///   - questionnaire: The questionnaire state machine map.
    ///   - workflow: The workflow state machine map.
    ///   - ownerID: Optional owner entity ID.
    /// - Returns: The created template.
    /// - Throws: `TemplateError.validationFailed` if validation fails, or other `TemplateError` types.
    public func createVersionWithValidation(
        gitRepositoryID: UUID,
        code: String,
        version: String,
        title: String,
        description: String,
        respondentType: RespondentType,
        markdownContent: String,
        frontmatter: [String: String],
        questionnaire: [String: [String: String]] = [:],
        workflow: [String: [String: String]] = [:],
        ownerID: UUID?
    ) async throws -> Template {
        let validations = validator.validate(
            title: title,
            description: description,
            respondentType: respondentType.rawValue,
            frontmatter: frontmatter,
            markdownContent: markdownContent
        )

        if !validations.isEmpty {
            throw TemplateError.validationFailed(validations)
        }

        return try await createVersion(
            gitRepositoryID: gitRepositoryID,
            code: code,
            version: version,
            title: title,
            description: description,
            respondentType: respondentType,
            markdownContent: markdownContent,
            frontmatter: frontmatter,
            questionnaire: questionnaire,
            workflow: workflow,
            ownerID: ownerID
        )
    }
}

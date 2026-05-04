import Foundation
import Logging
import NavigatorDAL
import NavigatorRules

/// Imports markdown template files into the database.
public struct TemplateImporter {
    private let templateService: TemplateService
    private let logger: Logger
    private let parser = FrontmatterParser()

    public init(templateService: TemplateService, logger: Logger) {
        self.templateService = templateService
        self.logger = logger
    }

    /// Imports a markdown file as a template version.
    ///
    /// - Parameters:
    ///   - fileURL: The markdown file to import
    ///   - gitRepositoryID: The git repository ID
    ///   - version: The git commit SHA
    /// - Returns: The created template
    /// - Throws: `TemplateError` if validation fails or required fields are missing
    public func importMarkdownFile(
        _ fileURL: URL,
        gitRepositoryID: UUID,
        version: String
    ) async throws -> Template {
        logger.info("Importing template from \(fileURL.path)")

        let content = try String(contentsOf: fileURL, encoding: .utf8)

        guard let (frontmatter, markdownContent) = parser.parse(content) else {
            throw TemplateError.invalidFrontmatter("File must have valid YAML frontmatter")
        }

        guard let title = frontmatter["title"], !title.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw TemplateError.missingRequiredField("title")
        }

        guard
            let description = frontmatter["description"],
            !description.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw TemplateError.missingRequiredField("description")
        }

        guard let respondentTypeRaw = frontmatter["respondent_type"],
            let respondentType = RespondentType(rawValue: respondentTypeRaw)
        else {
            throw TemplateError.missingRequiredField("respondent_type")
        }

        let yaml = try parser.parseYAML(content, as: TemplateYAML.self)
        let questionnaire = yaml?.questionnaire ?? [:]
        let workflow = yaml?.workflow ?? [:]

        let code = fileURL.deletingPathExtension().lastPathComponent

        logger.debug("Creating template with code: \(code), title: \(title)")

        let template = try await templateService.createVersionWithValidation(
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
            ownerID: nil
        )

        logger.info("Successfully imported template: \(code) - \(title)")

        return template
    }
}

private struct TemplateYAML: Decodable {
    let questionnaire: [String: [String: String]]?
    let workflow: [String: [String: String]]?
}

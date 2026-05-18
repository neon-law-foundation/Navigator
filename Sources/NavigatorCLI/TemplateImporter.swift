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

        guard let yaml = try parser.parseYAML(content, as: TemplateYAML.self) else {
            throw TemplateError.invalidFrontmatter("File must have valid YAML frontmatter")
        }

        guard let (_, markdownContent) = parser.parse(content) else {
            throw TemplateError.invalidFrontmatter("File must have valid YAML frontmatter")
        }

        let code = fileURL.deletingPathExtension().lastPathComponent
        let frontmatter = Frontmatter(
            title: yaml.title,
            respondentType: yaml.respondentType,
            code: code,
            confidential: yaml.confidential ?? false,
            description: yaml.description
        )

        logger.debug("Creating template with code: \(code), title: \(yaml.title)")

        let template = try await templateService.createVersion(
            gitRepositoryID: gitRepositoryID,
            version: version,
            frontmatter: frontmatter,
            markdownContent: markdownContent,
            questionnaire: yaml.questionnaire ?? Questionnaire(),
            workflow: yaml.workflow ?? Workflow(),
            ownerID: nil
        )

        logger.info("Successfully imported template: \(code) - \(yaml.title)")

        return template
    }
}

private struct TemplateYAML: Decodable {
    let title: String
    let description: String?
    let respondentType: RespondentType
    let confidential: Bool?
    let questionnaire: Questionnaire?
    let workflow: Workflow?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case respondentType = "respondent_type"
        case confidential
        case questionnaire
        case workflow
    }
}

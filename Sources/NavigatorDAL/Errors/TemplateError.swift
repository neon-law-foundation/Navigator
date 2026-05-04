import Foundation

/// Errors related to template operations and version management.
public enum TemplateError: Error, LocalizedError {

    /// Attempted to create a template version that already exists.
    case versionAlreadyExists(repository: UUID, code: String, version: String)

    /// Template with specified repository and code not found.
    case notFound(repository: UUID, code: String)

    /// No versions found for the specified template.
    case noVersionsFound(repository: UUID, code: String)

    /// Template failed validation.
    case validationFailed([TemplateValidation])

    /// Invalid frontmatter format or content.
    case invalidFrontmatter(String)

    /// Required field is missing from template data.
    case missingRequiredField(String)

    /// A template with the same title already exists in this repository.
    case titleAlreadyExists(String)

    public var errorDescription: String? {
        switch self {
        case .versionAlreadyExists(let repo, let code, let version):
            return
                "Template '\(code)' version '\(version)' already exists in repository \(repo)"
        case .notFound(let repo, let code):
            return "Template '\(code)' not found in repository \(repo)"
        case .noVersionsFound(let repo, let code):
            return "No versions found for template '\(code)' in repository \(repo)"
        case .validationFailed(let validations):
            let messages = validations.map { validation in
                var parts = ["[\(validation.violation.ruleCode)]"]
                if let field = validation.field {
                    parts.append("\(field):")
                }
                parts.append(validation.violation.message)
                return parts.joined(separator: " ")
            }
            return "Template validation failed:\n" + messages.joined(separator: "\n")
        case .invalidFrontmatter(let message):
            return "Invalid frontmatter: \(message)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .titleAlreadyExists(let title):
            return "Template with title '\(title)' already exists in this repository"
        }
    }

}

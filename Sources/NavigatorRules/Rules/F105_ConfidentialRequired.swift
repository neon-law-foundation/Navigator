import Foundation

/// F105: Frontmatter must contain a 'confidential' field set to true or false
public struct F105_ConfidentialRequired: Rule {
    public let code = "F105"
    public let description = "Frontmatter must contain a 'confidential' field set to true or false"

    private let parser = FrontmatterParser()

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        if file.lastPathComponent.lowercased() == "readme.md" {
            return []
        }

        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        guard parser.hasFrontmatter(content) else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Missing frontmatter with confidential field"
                )
            ]
        }

        guard let (frontmatter, _) = parser.parse(content) else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Missing frontmatter with confidential field"
                )
            ]
        }

        guard let value = frontmatter["confidential"] else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Frontmatter must contain a 'confidential' field"
                )
            ]
        }

        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed == "true" || trimmed == "false" else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Frontmatter 'confidential' field must be 'true' or 'false'"
                )
            ]
        }

        return []
    }
}

import Foundation

/// F101: Frontmatter must contain a non-empty title field
public struct F101_TitleRequired: Rule {
    public let code = "F101"
    public let description = "Frontmatter must contain a non-empty title field"

    private let parser = FrontmatterParser()

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        guard parser.hasFrontmatter(content) else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Missing frontmatter with title field"
                )
            ]
        }

        guard let (frontmatter, _) = parser.parse(content) else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Missing frontmatter with title field"
                )
            ]
        }

        if let title = frontmatter["title"], !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return []
        }

        return [
            Violation(
                ruleCode: code,
                message: "Frontmatter must contain a non-empty title field"
            )
        ]
    }
}

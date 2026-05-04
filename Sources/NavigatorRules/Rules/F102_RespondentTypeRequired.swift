import Foundation

/// F102: Frontmatter must contain a valid respondent_type field
public struct F102_RespondentTypeRequired: Rule {
    public let code = "F102"
    public let description =
        "Frontmatter must contain a valid respondent_type field (entity, person, or person_and_entity)"

    private let validValues = ["entity", "person", "person_and_entity"]
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
                    message: "Missing frontmatter with respondent_type field"
                )
            ]
        }

        guard let (frontmatter, _) = parser.parse(content) else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Missing frontmatter with respondent_type field"
                )
            ]
        }

        guard let respondentType = frontmatter["respondent_type"],
            !respondentType.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return [
                Violation(
                    ruleCode: code,
                    message: "Frontmatter must contain a non-empty respondent_type field",
                    context: ["valid_values": validValues.joined(separator: ", ")]
                )
            ]
        }

        if !validValues.contains(respondentType) {
            return [
                Violation(
                    ruleCode: code,
                    message: "Invalid respondent_type value: '\(respondentType)'",
                    context: [
                        "value": respondentType,
                        "valid_values": validValues.joined(separator: ", "),
                    ]
                )
            ]
        }

        return []
    }
}

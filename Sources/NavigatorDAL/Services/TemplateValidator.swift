import Foundation
import NavigatorRules

/// Validates template data before saving to the database.
public struct TemplateValidator {
    public init() {}

    /// Validates template fields.
    ///
    /// - Parameters:
    ///   - title: The template title
    ///   - description: The template description
    ///   - respondentType: The respondent type value
    ///   - frontmatter: The full frontmatter dictionary
    ///   - markdownContent: The markdown content
    /// - Returns: Array of validation failures (empty if valid)
    public func validate(
        title: String,
        description: String,
        respondentType: String,
        frontmatter: [String: String],
        markdownContent: String
    ) -> [TemplateValidation] {
        var validations: [TemplateValidation] = []

        validations.append(contentsOf: validateTitle(title))
        validations.append(contentsOf: validateRespondentType(respondentType))

        return validations
    }

    private func validateTitle(_ title: String) -> [TemplateValidation] {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            return [
                TemplateValidation(
                    violation: Violation(
                        ruleCode: "F101",
                        message: "Title must not be empty"
                    ),
                    field: "title"
                )
            ]
        }
        return []
    }

    private func validateRespondentType(_ respondentType: String) -> [TemplateValidation] {
        let validRespondentTypes = ["entity", "person", "person_and_entity"]

        if !validRespondentTypes.contains(respondentType) {
            return [
                TemplateValidation(
                    violation: Violation(
                        ruleCode: "F102",
                        message: "Invalid respondent_type: '\(respondentType)'",
                        context: [
                            "value": respondentType,
                            "valid_values": validRespondentTypes.joined(separator: ", "),
                        ]
                    ),
                    field: "respondent_type"
                )
            ]
        }
        return []
    }
}

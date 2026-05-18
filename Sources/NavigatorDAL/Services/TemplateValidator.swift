import Foundation
import NavigatorRules

/// Validates a ``Frontmatter`` value before persistence.
///
/// `Frontmatter`'s type signature already enforces every "field present" and
/// "respondent type is a known enum" check the legacy string-keyed validator
/// did. The only rule that does not fall out of the type system is "title must
/// not be whitespace-only", so that is the only check this validator now
/// performs.
public struct TemplateValidator {
    public init() {}

    public func validate(_ frontmatter: Frontmatter) -> [TemplateValidation] {
        if frontmatter.title.trimmingCharacters(in: .whitespaces).isEmpty {
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
}

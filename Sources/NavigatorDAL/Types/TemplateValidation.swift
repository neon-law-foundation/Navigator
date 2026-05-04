import Foundation
import NavigatorRules

/// Represents a validation failure for a ``Template`` model.
public struct TemplateValidation: Sendable {
    /// The underlying rule violation.
    public let violation: Violation

    /// The specific field that failed validation, if applicable.
    public let field: String?

    public init(violation: Violation, field: String? = nil) {
        self.violation = violation
        self.field = field
    }
}

import Foundation

/// A unified violation type for all rules
public struct Violation: Equatable, Sendable {
    /// Machine-readable rule code (e.g., "S101", "F101")
    public let ruleCode: String

    /// Human-readable error message
    public let message: String

    /// Optional line number where violation occurred
    public let line: Int?

    /// Optional additional context (e.g., "length": "150", "max": "120")
    public let context: [String: String]?

    public init(
        ruleCode: String,
        message: String,
        line: Int? = nil,
        context: [String: String]? = nil
    ) {
        self.ruleCode = ruleCode
        self.message = message
        self.line = line
        self.context = context
    }
}

/// Results for a single file
public struct FileViolations: Equatable, Sendable {
    public let file: URL
    public let violations: [Violation]

    public var isValid: Bool {
        violations.isEmpty
    }

    public init(file: URL, violations: [Violation]) {
        self.file = file
        self.violations = violations
    }
}

/// Aggregated results across all files
public struct LintResult: Sendable {
    public let fileViolations: [FileViolations]

    public var isValid: Bool {
        fileViolations.allSatisfy(\.isValid)
    }

    public var totalViolationCount: Int {
        fileViolations.reduce(0) { $0 + $1.violations.count }
    }

    public init(fileViolations: [FileViolations]) {
        self.fileViolations = fileViolations
    }
}

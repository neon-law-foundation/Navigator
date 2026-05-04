import Foundation

/// Protocol defining a linting rule
public protocol Rule {
    /// Unique rule code (e.g., "S101", "F101")
    var code: String { get }

    /// Human-readable rule description
    var description: String { get }

    /// Validate a single file and return violations
    func validate(file: URL) throws -> [Violation]
}

/// Protocol for rules that support auto-fixing
public protocol FixableRule: Rule {
    /// Apply fixes to the file at the given URL
    /// Returns the number of violations fixed
    func fix(file: URL) async throws -> Int
}

import Foundation

/// M010: Lines must not contain hard tab characters.
///
/// Mirrors markdownlint's MD010 (no-hard-tabs). Fix replaces each tab with four spaces.
public struct M010_NoHardTabs: FixableRule {
    public let code = "M010"
    public let description = "Lines must not contain hard tab characters"

    private static let spacesPerTab = 4

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where line.raw.contains("\t") {
            violations.append(
                Violation(
                    ruleCode: code,
                    message: "Line contains a hard tab character",
                    line: line.number
                )
            )
        }
        return violations
    }

    public func fix(file: URL) async throws -> Int {
        let violationsBeforeFix = try validate(file: file)
        guard !violationsBeforeFix.isEmpty else { return 0 }

        let content = try String(contentsOf: file, encoding: .utf8)
        let replacement = String(repeating: " ", count: Self.spacesPerTab)
        let fixed = content.replacingOccurrences(of: "\t", with: replacement)
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }
}

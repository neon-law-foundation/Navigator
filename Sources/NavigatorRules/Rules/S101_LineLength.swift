import Foundation

/// S101: All lines must be ≤120 characters
public struct S101_LineLength: FixableRule {
    public let code = "S101"
    public let description = "Line length must not exceed 120 characters"
    private let maxLength = 120

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var violations: [Violation] = []
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let length = line.count

            if length > maxLength {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Line exceeds maximum length",
                        line: lineNumber,
                        context: [
                            "length": "\(length)",
                            "max": "\(maxLength)",
                        ]
                    )
                )
            }
        }

        return violations
    }

    /// Reflows long lines deterministically using ``LineWrapper``.
    ///
    /// Returns the count of S101 violations the rewrite eliminated. Lines that
    /// cannot be safely reflowed (fenced code blocks, tables, link reference
    /// definitions, headings, HTML, single tokens longer than `maxLength`)
    /// are left in place and continue to report as violations.
    public func fix(file: URL) async throws -> Int {
        let before = try validate(file: file).count
        guard before > 0 else { return 0 }

        let original = try String(contentsOf: file, encoding: .utf8)
        let wrapped = LineWrapper.wrap(original, maxLength: maxLength)

        if wrapped != original {
            try wrapped.write(to: file, atomically: true, encoding: .utf8)
        }

        let after = try validate(file: file).count
        return max(0, before - after)
    }
}

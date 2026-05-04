import Foundation

/// M012: No more than one consecutive blank line.
///
/// Mirrors markdownlint's MD012 (no-multiple-blanks) with the default `maximum: 1`.
/// The final blank line produced by a trailing newline is ignored so this rule does
/// not double-report with M047.
public struct M012_NoMultipleBlanks: FixableRule {
    public let code = "M012"
    public let description = "No more than one consecutive blank line"
    private static let maximum = 1

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = LineScanner.scan(content)
        let lastIndexIsTrailingNewline = content.hasSuffix("\n") && lines.last?.raw.isEmpty == true

        var violations: [Violation] = []
        var blankRun = 0
        for (index, line) in lines.enumerated() {
            let isLastTrailing = lastIndexIsTrailingNewline && index == lines.count - 1
            if line.isBlank, !isLastTrailing {
                blankRun += 1
                if blankRun > Self.maximum {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "More than \(Self.maximum) consecutive blank line(s)",
                            line: line.number
                        )
                    )
                }
            } else {
                blankRun = 0
            }
        }
        return violations
    }

    public func fix(file: URL) async throws -> Int {
        let violationsBeforeFix = try validate(file: file)
        guard !violationsBeforeFix.isEmpty else { return 0 }

        let content = try String(contentsOf: file, encoding: .utf8)
        let trailingNewline = content.hasSuffix("\n")
        let lines = content.components(separatedBy: "\n")

        var rebuilt: [String] = []
        rebuilt.reserveCapacity(lines.count)
        var blankRun = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blankRun += 1
                if blankRun <= Self.maximum {
                    rebuilt.append(line)
                }
            } else {
                blankRun = 0
                rebuilt.append(line)
            }
        }

        // `components(separatedBy: "\n")` on content ending in \n emits a trailing empty
        // element. Collapsing blank runs eats it, so restore it to keep the final newline.
        if trailingNewline, rebuilt.last?.isEmpty != true {
            rebuilt.append("")
        }

        let fixed = rebuilt.joined(separator: "\n")
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }
}

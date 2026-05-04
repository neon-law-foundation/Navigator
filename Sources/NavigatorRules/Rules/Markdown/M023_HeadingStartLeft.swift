import Foundation

/// M023: Headings must start at the beginning of the line.
///
/// Mirrors markdownlint's MD023 (heading-start-left). Phase 1 handles ATX headings;
/// setext headings (block-level) are deferred to Phase 2.
public struct M023_HeadingStartLeft: FixableRule {
    public let code = "M023"
    public let description = "Headings must start at the beginning of the line"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            if Self.headingIndent(in: line.raw)?.isEmpty == false {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Heading does not start at the beginning of the line",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }

    public func fix(file: URL) async throws -> Int {
        let violationsBeforeFix = try validate(file: file)
        guard !violationsBeforeFix.isEmpty else { return 0 }

        let content = try String(contentsOf: file, encoding: .utf8)
        let scanned = LineScanner.scan(content)
        let lines = content.components(separatedBy: "\n")

        var rebuilt: [String] = []
        rebuilt.reserveCapacity(lines.count)
        for (index, line) in lines.enumerated() {
            let isFrontmatter = index < scanned.count ? scanned[index].isInFrontmatter : false
            if !isFrontmatter, let indent = Self.headingIndent(in: line), !indent.isEmpty {
                rebuilt.append(String(line.dropFirst(indent.count)))
            } else {
                rebuilt.append(line)
            }
        }

        let fixed = rebuilt.joined(separator: "\n")
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }

    /// The 0-3 space indent on an ATX heading line, or `nil` if the line is not an ATX heading.
    private static func headingIndent(in line: String) -> String? {
        // Try open ATX first.
        if let parts = ATXHeadingParser.parse(line) {
            return parts.indent
        }
        // Fall back to tolerant closed-ATX parse (covers e.g. `  # Heading#` where parse
        // refuses because the close isn't whitespace-preceded).
        if let closed = ATXHeadingParser.parseClosed(line) {
            return closed.indent
        }
        return nil
    }
}

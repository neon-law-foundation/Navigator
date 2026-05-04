import Foundation

/// M019: ATX headings must have exactly one space between the hash marks and the heading text.
///
/// Mirrors markdownlint's MD019 (no-multiple-space-atx).
public struct M019_NoMultipleSpaceATX: FixableRule {
    public let code = "M019"
    public let description = "ATX headings must have a single space after the hash"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            if Self.hasExtraSpacesAfterHashes(in: line.raw) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Multiple spaces after hash on ATX heading",
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
            if !isFrontmatter, Self.hasExtraSpacesAfterHashes(in: line) {
                rebuilt.append(Self.collapseSpacesAfterHashes(in: line))
            } else {
                rebuilt.append(line)
            }
        }

        let fixed = rebuilt.joined(separator: "\n")
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }

    private static func hasExtraSpacesAfterHashes(in line: String) -> Bool {
        guard let parts = ATXHeadingParser.parse(line) else { return false }
        let middle = parts.middle
        guard middle.count >= 2 else { return false }
        let firstTwo = middle.prefix(2)
        return firstTwo.allSatisfy { $0 == " " }
    }

    private static func collapseSpacesAfterHashes(in line: String) -> String {
        guard let parts = ATXHeadingParser.parse(line) else { return line }
        let collapsed = " " + parts.middle.drop(while: { $0 == " " })
        return parts.indent + parts.openingHashes + collapsed + parts.closing
    }
}

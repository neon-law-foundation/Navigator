import Foundation

/// M018: ATX headings must have a space between the hash marks and the heading text.
///
/// Mirrors markdownlint's MD018 (no-missing-space-atx).
public struct M018_NoMissingSpaceATX: FixableRule {
    public let code = "M018"
    public let description = "ATX headings must have a space after the hash"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let codeLines = BlockTokenizer.linesInsideCodeBlocks(content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            if codeLines.contains(line.number) { continue }
            if ATXHeadingParser.missingSpaceAfterHashes(in: line.raw) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Missing space after hash on ATX heading",
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
        let lines = content.components(separatedBy: "\n")
        var rebuilt: [String] = []
        rebuilt.reserveCapacity(lines.count)

        let scanned = LineScanner.scan(content)
        let codeLines = BlockTokenizer.linesInsideCodeBlocks(content)
        for (index, line) in lines.enumerated() {
            let isFrontmatter = index < scanned.count ? scanned[index].isInFrontmatter : false
            let lineNumber = index + 1
            let isInCode = codeLines.contains(lineNumber)
            if !isFrontmatter, !isInCode, ATXHeadingParser.missingSpaceAfterHashes(in: line) {
                rebuilt.append(ATXHeadingParser.insertSpaceAfterHashes(in: line))
            } else {
                rebuilt.append(line)
            }
        }

        let fixed = rebuilt.joined(separator: "\n")
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }
}

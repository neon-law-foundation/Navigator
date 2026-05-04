import Foundation

/// M027: Block quote lines must not have multiple spaces after the `>` marker.
///
/// Mirrors markdownlint's MD027 (no-multiple-space-blockquote).
public struct M027_NoMultipleSpaceBlockquote: Rule {
    public let code = "M027"
    public let description = "Block quotes must use a single space after the `>` marker"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            if Self.hasMultipleSpacesAfterMarker(in: line.raw) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Multiple spaces after blockquote marker",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }

    /// Return true when the line begins a block quote (optionally indented up to 3 spaces)
    /// and has two or more spaces/tabs between any `>` marker and the content that follows it.
    private static func hasMultipleSpacesAfterMarker(in line: String) -> Bool {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex, line[cursor] == ">" else { return false }

        while cursor < line.endIndex, line[cursor] == ">" {
            cursor = line.index(after: cursor)
            var whitespaceCount = 0
            while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
                cursor = line.index(after: cursor)
                whitespaceCount += 1
            }
            // Pure-whitespace remainder doesn't trigger here (M009 handles trailing whitespace).
            if whitespaceCount >= 2, cursor < line.endIndex, line[cursor] != ">" {
                return true
            }
        }
        return false
    }
}

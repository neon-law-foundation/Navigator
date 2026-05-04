import Foundation

/// M039: Link and image text must not have leading or trailing whitespace inside brackets.
///
/// Mirrors markdownlint's MD039 (no-space-in-links). `[ label ](url)` renders with the spaces
/// intact — the author probably meant `[label](url)`.
public struct M039_NoSpaceInLinks: Rule {
    public let code = "M039"
    public let description = "Link text must not have internal padding"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let skipLines = ReferenceCollector.linesToSkip(content: content)
        let knownLabels = ReferenceCollector.knownLabels(from: content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) {
            if skipLines.contains(line.number) { continue }
            if line.isInFrontmatter { continue }
            let links = InlineTokenizer.inlineLinks(in: line.raw, knownLabels: knownLabels)
            for link in links where link.textHasLeadingSpace || link.textHasTrailingSpace {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Link text has leading or trailing whitespace",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }
}

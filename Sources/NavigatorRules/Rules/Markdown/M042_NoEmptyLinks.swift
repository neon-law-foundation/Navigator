import Foundation

/// M042: Links must have both text and a destination.
///
/// Mirrors markdownlint's MD042 (no-empty-links). Flags `[]()`, `[text]()`, `[](url)`, and
/// reference-style forms with empty labels. Fragments-only destinations (`(#)`) count as empty.
public struct M042_NoEmptyLinks: Rule {
    public let code = "M042"
    public let description = "Links must have text and a destination"

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
            for link in links where !link.isImage {
                let text = String(line.raw[link.textRange]).trimmingCharacters(in: .whitespaces)
                let isEmpty: Bool
                switch link.kind {
                case .inline:
                    let dest =
                        link.destinationRange.map {
                            String(line.raw[$0]).trimmingCharacters(in: .whitespaces)
                        } ?? ""
                    isEmpty = text.isEmpty || Self.isEmptyDestination(dest)
                case .reference, .collapsed, .shortcut:
                    isEmpty = text.isEmpty
                }
                if isEmpty {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Link has empty text or destination",
                            line: line.number
                        )
                    )
                }
            }
        }
        return violations
    }

    /// A destination is empty when it contains nothing, just a `#`, or only whitespace.
    static func isEmptyDestination(_ dest: String) -> Bool {
        let trimmed = dest.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        if trimmed == "#" { return true }
        return false
    }
}

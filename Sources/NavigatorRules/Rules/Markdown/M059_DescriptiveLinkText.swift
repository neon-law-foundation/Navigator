import Foundation

/// M059: Link text must be descriptive — not generic phrases or the bare URL.
///
/// Mirrors markdownlint's MD059 (descriptive-link-text). The visible link text is normalized
/// (inline markup stripped, whitespace trimmed, lowercased) and compared against a fixed list
/// of non-descriptive phrases. A link whose text is the URL itself (`http://`, `https://`, or
/// `www.`) is also flagged as non-descriptive — readers can't tell what's on the other end.
///
/// Image links are skipped (their accessibility is covered by M045). Reference-link
/// definitions (`[label]: url`) are also skipped.
public struct M059_DescriptiveLinkText: Rule {
    public let code = "M059"
    public let description = "Link text must be descriptive"

    public init() {}

    static let prohibitedTexts: Set<String> = [
        "click here",
        "here",
        "link",
        "more",
        "read more",
    ]

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
            if ReferenceCollector.isReferenceDefinitionLine(line.raw) { continue }
            let links = InlineTokenizer.inlineLinks(in: line.raw, knownLabels: knownLabels)
            for link in links where !link.isImage {
                let rawText = String(line.raw[link.textRange])
                let visible = Self.visibleText(of: rawText).trimmingCharacters(in: .whitespaces)
                if visible.isEmpty { continue }
                let normalized = visible.lowercased()
                let reason: String?
                if Self.prohibitedTexts.contains(normalized) {
                    reason = "Link text is not descriptive"
                } else if Self.isURL(normalized) {
                    reason = "Link text is a bare URL"
                } else {
                    reason = nil
                }
                if let reason {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "\(reason): \(visible)",
                            line: line.number,
                            context: ["text": visible]
                        )
                    )
                }
            }
        }
        return violations
    }

    /// Cheap fast path — only invoke the full inline-markup stripper when the text actually
    /// contains a markup sigil. The prohibited-text list and URL prefixes contain none of these
    /// characters, so plain text already-trimmed is the common case.
    static func visibleText(of text: String) -> String {
        if text.contains(where: { "`*_[".contains($0) }) {
            return InlineTokenizer.stripInlineMarkup(text)
        }
        return text
    }

    static func isURL(_ text: String) -> Bool {
        text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("www.")
    }
}

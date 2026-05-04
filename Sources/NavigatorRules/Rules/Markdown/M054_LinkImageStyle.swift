import Foundation

/// M054: Link and image syntax style should be consistent across the document.
///
/// Mirrors markdownlint's MD054 (link-image-style) with the default style: all link styles
/// are allowed, but autolinks with a URL-scheme that could be written as inline links and
/// obvious misuses (e.g. `[text](url)` for URL-only text) aren't enforced here. The Phase 4
/// port uses a pragmatic default: flag only the most obvious misuses markdownlint's default
/// config enables — `url_inline` where the link text equals the URL destination, since that
/// duplication is purely stylistic. The other sub-options (autolink, inline, collapsed, etc.)
/// default to permitted.
public struct M054_LinkImageStyle: Rule {
    public let code = "M054"
    public let description = "Link and image style should be consistent"

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
            for link in links {
                guard link.kind == .inline, !link.isImage,
                    let destRange = link.destinationRange
                else { continue }
                let text = String(line.raw[link.textRange]).trimmingCharacters(in: .whitespaces)
                var destination = String(line.raw[destRange]).trimmingCharacters(
                    in: .whitespaces
                )
                if destination.hasPrefix("<"), destination.hasSuffix(">") {
                    destination = String(destination.dropFirst().dropLast())
                }
                if !text.isEmpty, text == destination {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message:
                                "Link text duplicates the URL — use an autolink `<url>` instead",
                            line: line.number,
                            context: ["url": destination]
                        )
                    )
                }
            }
        }
        return violations
    }
}

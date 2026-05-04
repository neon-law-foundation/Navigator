import Foundation

/// M045: Images must include alt text.
///
/// Mirrors markdownlint's MD045 (no-alt-text). `![](url)` and `![][label]` have empty alt —
/// the image is invisible to screen readers and broken images show nothing.
public struct M045_NoAltText: Rule {
    public let code = "M045"
    public let description = "Images must include alt text"

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
            for link in links where link.isImage {
                // For collapsed/shortcut reference images, the label acts as the alt text —
                // so `![foo][]` and `![foo]` are not empty.
                guard link.kind == .inline || link.kind == .reference else { continue }
                let alt = String(line.raw[link.textRange]).trimmingCharacters(in: .whitespaces)
                if alt.isEmpty {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Image is missing alt text",
                            line: line.number
                        )
                    )
                }
            }
        }
        return violations
    }
}

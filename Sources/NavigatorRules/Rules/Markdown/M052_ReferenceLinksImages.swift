import Foundation

/// M052: Every reference-link label used must be defined.
///
/// Mirrors markdownlint's MD052 (reference-links-images). Flags reference/collapsed uses whose
/// normalized label has no matching definition. Shortcut uses that don't resolve are not
/// recognized as reference links in the first place, so they are never counted here.
public struct M052_ReferenceLinksImages: Rule {
    public let code = "M052"
    public let description = "Reference-link labels must be defined"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let knownLabels = ReferenceCollector.knownLabels(from: content)
        let skipLines = ReferenceCollector.linesToSkip(content: content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) {
            if skipLines.contains(line.number) { continue }
            if line.isInFrontmatter { continue }
            if ReferenceCollector.isReferenceDefinitionLine(line.raw) { continue }
            // Pass an empty knownLabels set so ALL reference shapes surface regardless of
            // resolvability — we need to flag the unresolved ones.
            let links = InlineTokenizer.inlineLinks(in: line.raw, knownLabels: [])
            for link in links {
                guard link.kind == .reference || link.kind == .collapsed else { continue }
                let raw =
                    link.kind == .reference && link.labelRange != nil
                    ? String(line.raw[link.labelRange!])
                    : String(line.raw[link.textRange])
                let normalized = InlineTokenizer.normalizeLabel(raw)
                if !normalized.isEmpty, !knownLabels.contains(normalized) {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Reference label is not defined",
                            line: line.number,
                            context: ["label": raw]
                        )
                    )
                }
            }
        }
        return violations
    }
}

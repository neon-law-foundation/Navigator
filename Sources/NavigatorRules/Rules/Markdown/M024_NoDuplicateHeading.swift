import Foundation

/// M024: No two headings under the same parent may share the same text.
///
/// Mirrors markdownlint's MD024 (no-duplicate-heading) configured with `siblings_only: true`:
/// duplicates are only flagged when both headings share the same chain of ancestor headings.
/// Two headings with identical text but different parent paths are allowed.
///
/// Comparison is case-insensitive after trimming surrounding whitespace. Inline markup is left
/// in place so `## Foo` and `## **Foo**` are treated as distinct (matching upstream behavior).
public struct M024_NoDuplicateHeading: Rule {
    public let code = "M024"
    public let description = "No duplicate headings under the same parent"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        var ancestors: [String] = []
        var seenByPath: [[String]: Set<String>] = [:]

        for block in blocks {
            guard case .heading(let level, _, let text) = block.kind else { continue }
            let parentCount = max(1, min(level, 6)) - 1
            if ancestors.count > parentCount {
                ancestors.removeSubrange(parentCount..<ancestors.count)
            }
            while ancestors.count < parentCount { ancestors.append("") }

            let normalized = text.trimmingCharacters(in: .whitespaces).lowercased()
            var seen = seenByPath[ancestors] ?? []
            if seen.contains(normalized) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Duplicate heading under the same parent: \(text)",
                        line: block.startLine,
                        context: ["text": text]
                    )
                )
            } else {
                seen.insert(normalized)
                seenByPath[ancestors] = seen
            }

            ancestors.append(text)
        }
        return violations
    }
}

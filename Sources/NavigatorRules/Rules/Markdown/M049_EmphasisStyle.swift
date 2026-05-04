import Foundation

/// M049: Emphasis must use a consistent marker (`*` or `_`).
///
/// Mirrors markdownlint's MD049 (emphasis-style) with the default `style: "consistent"`.
/// The marker used by the first emphasis run in the document becomes the baseline; any
/// subsequent single-marker emphasis using a different character is reported.
public struct M049_EmphasisStyle: Rule {
    public let code = "M049"
    public let description = "Emphasis marker must be consistent across the document"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let skipLines = ReferenceCollector.linesToSkip(content: content)

        var violations: [Violation] = []
        var expected: Character?
        for line in LineScanner.scan(content) {
            if skipLines.contains(line.number) { continue }
            if line.isInFrontmatter { continue }
            for run in InlineTokenizer.emphasisRuns(in: line.raw) where run.count == 1 {
                if let baseline = expected {
                    if run.marker != baseline {
                        violations.append(
                            Violation(
                                ruleCode: code,
                                message: "Emphasis marker does not match first-use marker",
                                line: line.number,
                                context: [
                                    "expected": String(baseline),
                                    "actual": String(run.marker),
                                ]
                            )
                        )
                    }
                } else {
                    expected = run.marker
                }
            }
        }
        return violations
    }
}

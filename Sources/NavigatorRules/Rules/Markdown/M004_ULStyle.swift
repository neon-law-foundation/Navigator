import Foundation

/// M004: Unordered list items must use a consistent bullet marker (`-`, `*`, or `+`).
///
/// Mirrors markdownlint's MD004 (ul-style) with the default `style: "consistent"`. The marker of
/// the first unordered item encountered becomes the baseline; any subsequent unordered item that
/// uses a different marker is reported.
public struct M004_ULStyle: Rule {
    public let code = "M004"
    public let description = "Unordered list items must use a consistent bullet marker"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        var violations: [Violation] = []
        var expected: Character?
        for parsed in ListParser.parseLists(in: content) {
            for item in parsed.items where !item.ordered {
                if let baseline = expected {
                    if item.markerDelim != baseline {
                        violations.append(
                            Violation(
                                ruleCode: code,
                                message: "Unordered list marker does not match first-use marker",
                                line: item.line,
                                context: [
                                    "expected": String(baseline),
                                    "actual": String(item.markerDelim),
                                ]
                            )
                        )
                    }
                } else {
                    expected = item.markerDelim
                }
            }
        }
        return violations
    }
}

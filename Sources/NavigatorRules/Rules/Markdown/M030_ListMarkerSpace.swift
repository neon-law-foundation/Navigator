import Foundation

/// M030: Exactly one whitespace character must separate a list marker from its content.
///
/// Mirrors markdownlint's MD030 (list-marker-space) with the defaults
/// `ul_single: 1, ol_single: 1, ul_multi: 1, ol_multi: 1`. Any item whose whitespace count
/// between the marker and its content differs from one is reported.
public struct M030_ListMarkerSpace: Rule {
    public let code = "M030"
    public let description = "List markers must be followed by exactly one space"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        var violations: [Violation] = []
        for parsed in ListParser.parseLists(in: content) {
            for item in parsed.items where item.spacesAfterMarker != 1 {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message:
                            "List marker should be followed by exactly 1 space, found \(item.spacesAfterMarker)",
                        line: item.line,
                        context: [
                            "expected": "1",
                            "actual": "\(item.spacesAfterMarker)",
                        ]
                    )
                )
            }
        }
        return violations
    }
}

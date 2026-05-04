import Foundation

/// M029: Ordered list items must use a consistent numbering style — either all `1.` or a
/// sequential `1.`, `2.`, `3.`, … progression starting at 1.
///
/// Mirrors markdownlint's MD029 (ol-prefix) with the default `style: "one_or_ordered"`.
///
/// Runs are scoped to (depth, parent). An unordered item at the same depth and parent breaks the
/// run; deeper nested items do not. Each run is classified independently.
public struct M029_OLPrefix: Rule {
    public let code = "M029"
    public let description = "Ordered list numbering must be consistent"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        var violations: [Violation] = []
        for parsed in ListParser.parseLists(in: content) {
            violations.append(contentsOf: validate(list: parsed))
        }
        violations.sort { ($0.line ?? 0) < ($1.line ?? 0) }
        return violations
    }

    private func validate(list: ParsedList) -> [Violation] {
        var openRuns: [ListItemGroupKey: [ListItem]] = [:]
        var finalizedRuns: [[ListItem]] = []

        for item in list.items {
            let key = ListItemGroupKey(item: item)
            if item.ordered {
                openRuns[key, default: []].append(item)
            } else if let existing = openRuns.removeValue(forKey: key) {
                finalizedRuns.append(existing)
            }
        }
        finalizedRuns.append(contentsOf: openRuns.values)

        var violations: [Violation] = []
        for run in finalizedRuns {
            violations.append(contentsOf: validate(run: run))
        }
        return violations
    }

    private func validate(run: [ListItem]) -> [Violation] {
        let values = run.compactMap(\.orderedValue)
        guard values.count == run.count, !values.isEmpty else { return [] }

        // "one" style: every item numbered 1.
        if values.allSatisfy({ $0 == 1 }) { return [] }

        // "ordered" style: starts at 1, increments by 1.
        let firstValue = values[0]
        if firstValue != 1 {
            return [
                Violation(
                    ruleCode: code,
                    message:
                        "Ordered list should start at 1 (or use all-1 style)",
                    line: run[0].line,
                    context: ["expected": "1", "actual": "\(firstValue)"]
                )
            ]
        }

        var violations: [Violation] = []
        for (index, value) in values.enumerated() {
            let expected = index + 1
            if value != expected {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message:
                            "Ordered list item should be numbered \(expected) but is \(value)",
                        line: run[index].line,
                        context: ["expected": "\(expected)", "actual": "\(value)"]
                    )
                )
            }
        }
        return violations
    }
}

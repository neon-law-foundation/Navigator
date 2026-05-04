import Foundation

/// M005: List items at the same level within the same parent must have consistent indentation.
///
/// Mirrors markdownlint's MD005 (list-indent). Items in a group (same depth, same parent) are
/// checked against two acceptable alignments:
///
/// - **Left-aligned** — every item shares the same marker column.
/// - **Right-aligned** — every item shares the same `markerColumn + markerWidth` (useful for
///   ordered lists that cross a digit boundary, e.g. `9.` and `10.`).
///
/// Any item whose marker column differs from the first item's and which breaks both alignments
/// is reported.
public struct M005_ListIndent: Rule {
    public let code = "M005"
    public let description = "List items at the same level must be indented consistently"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        var violations: [Violation] = []
        for parsed in ListParser.parseLists(in: content) {
            var groups: [ListItemGroupKey: [ListItem]] = [:]
            var order: [ListItemGroupKey] = []
            for item in parsed.items {
                let key = ListItemGroupKey(item: item)
                if groups[key] == nil { order.append(key) }
                groups[key, default: []].append(item)
            }
            for key in order {
                guard let items = groups[key], items.count > 1 else { continue }
                let first = items[0]
                let leftAligned = items.allSatisfy { $0.markerColumn == first.markerColumn }
                if leftAligned { continue }
                let rightEdge = first.markerColumn + first.markerWidth
                let rightAligned = items.allSatisfy {
                    $0.markerColumn + $0.markerWidth == rightEdge
                }
                if rightAligned { continue }
                for item in items.dropFirst() where item.markerColumn != first.markerColumn {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message:
                                "Inconsistent indentation for list items at the same level",
                            line: item.line,
                            context: [
                                "expected": "\(first.markerColumn)",
                                "actual": "\(item.markerColumn)",
                            ]
                        )
                    )
                }
            }
        }
        violations.sort { ($0.line ?? 0) < ($1.line ?? 0) }
        return violations
    }
}

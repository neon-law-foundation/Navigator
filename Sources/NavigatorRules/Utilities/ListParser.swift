import Foundation

/// A single list item's geometry, extracted from a `.list` block.
public struct ListItem: Sendable, Equatable {
    /// 1-indexed source line where the marker starts.
    public let line: Int
    /// 1-indexed column of the first character of the marker.
    public let markerColumn: Int
    /// Width of the marker itself: `1` for `-`/`*`/`+`, digits+1 for ordered (e.g., `10.` → 3).
    public let markerWidth: Int
    /// The terminating character of the marker: `-`, `*`, `+` for unordered; `.` or `)` for ordered.
    public let markerDelim: Character
    /// True when the item is ordered (`1.`, `2)`, …).
    public let ordered: Bool
    /// Numeric value for ordered items, `nil` for unordered.
    public let orderedValue: Int?
    /// Count of whitespace characters between the marker and the start of content.
    public let spacesAfterMarker: Int
    /// Nesting depth within the enclosing list block. `0` is top-level.
    public let depth: Int
    /// Index into the surrounding items array of this item's parent, or `nil` for top-level items.
    public let parentIndex: Int?

    /// Number of leading space columns before the marker.
    public var indent: Int { markerColumn - 1 }
    /// 1-indexed column where the item content begins.
    public var contentColumn: Int { markerColumn + markerWidth + spacesAfterMarker }

    public init(
        line: Int,
        markerColumn: Int,
        markerWidth: Int,
        markerDelim: Character,
        ordered: Bool,
        orderedValue: Int?,
        spacesAfterMarker: Int,
        depth: Int,
        parentIndex: Int?
    ) {
        self.line = line
        self.markerColumn = markerColumn
        self.markerWidth = markerWidth
        self.markerDelim = markerDelim
        self.ordered = ordered
        self.orderedValue = orderedValue
        self.spacesAfterMarker = spacesAfterMarker
        self.depth = depth
        self.parentIndex = parentIndex
    }
}

/// Shared grouping key used by list rules that partition items by (depth, parent).
public struct ListItemGroupKey: Hashable, Sendable {
    public let depth: Int
    public let parentIndex: Int?

    public init(item: ListItem) {
        self.depth = item.depth
        self.parentIndex = item.parentIndex
    }
}

/// Geometry for a single `.list` block — the items in order plus the originating block range.
public struct ParsedList: Sendable, Equatable {
    /// 1-indexed inclusive start line of the enclosing list block.
    public let startLine: Int
    /// 1-indexed inclusive end line of the enclosing list block.
    public let endLine: Int
    /// The items contained in this list block, in source order.
    public let items: [ListItem]

    public init(startLine: Int, endLine: Int, items: [ListItem]) {
        self.startLine = startLine
        self.endLine = endLine
        self.items = items
    }
}

/// Parses `.list` blocks emitted by `BlockTokenizer` into per-item geometry usable by list rules.
///
/// Phase 3 list rules (MD004, MD005, MD007, MD029, MD030) need to know each item's indent,
/// marker, spacing, and nesting depth — information that `BlockTokenizer`'s coarse `.list` block
/// does not expose. This parser walks the raw lines of a list block, recognizes each item start,
/// computes nesting depth via a stack of ancestor content columns, and records parent indices.
public enum ListParser {
    /// Parse every `.list` block in `content` into `ParsedList` values.
    public static func parseLists(in content: String) -> [ParsedList] {
        let lines = splitLines(content)
        let blocks = BlockTokenizer.tokenize(content)
        var parsed: [ParsedList] = []
        for block in blocks {
            guard case .list = block.kind else { continue }
            parsed.append(parse(block: block, lines: lines))
        }
        return parsed
    }

    /// Parse a single `.list` block into a `ParsedList`.
    ///
    /// Non-list callers should prefer `parseLists(in:)`. This overload exists for rules that
    /// already iterate blocks and want to avoid re-tokenizing.
    public static func parse(block: Block, lines: [String]) -> ParsedList {
        guard case .list = block.kind else {
            return ParsedList(startLine: block.startLine, endLine: block.endLine, items: [])
        }
        var items: [ListItem] = []
        var ancestors: [(contentColumn: Int, index: Int)] = []

        let startIdx = block.startLine - 1
        let endIdx = block.endLine - 1
        if startIdx < 0 || endIdx >= lines.count {
            return ParsedList(startLine: block.startLine, endLine: block.endLine, items: [])
        }

        for lineIdx in startIdx...endIdx {
            let line = lines[lineIdx]
            guard let raw = parseItemStart(line: line) else { continue }

            // Pop ancestors whose content column is to the right of this marker — the marker
            // falls outside their content span, so they cannot be ancestors.
            while let top = ancestors.last, top.contentColumn > raw.markerColumn {
                ancestors.removeLast()
            }
            let item = ListItem(
                line: lineIdx + 1,
                markerColumn: raw.markerColumn,
                markerWidth: raw.markerWidth,
                markerDelim: raw.markerDelim,
                ordered: raw.ordered,
                orderedValue: raw.orderedValue,
                spacesAfterMarker: raw.spacesAfter,
                depth: ancestors.count,
                parentIndex: ancestors.last?.index
            )
            items.append(item)
            ancestors.append((item.contentColumn, items.count - 1))
        }

        return ParsedList(startLine: block.startLine, endLine: block.endLine, items: items)
    }

    // MARK: - Line parsing

    private struct RawItem {
        let markerColumn: Int
        let markerWidth: Int
        let markerDelim: Character
        let ordered: Bool
        let orderedValue: Int?
        let spacesAfter: Int
    }

    private static func parseItemStart(line: String) -> RawItem? {
        var indent = 0
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor] == " " {
            indent += 1
            cursor = line.index(after: cursor)
        }
        guard cursor < line.endIndex else { return nil }

        let first = line[cursor]
        let markerDelim: Character
        let markerWidth: Int
        let ordered: Bool
        let orderedValue: Int?

        if first == "-" || first == "*" || first == "+" {
            markerDelim = first
            markerWidth = 1
            ordered = false
            orderedValue = nil
            cursor = line.index(after: cursor)
        } else if first.isNumber {
            var value = 0
            var digitCount = 0
            while cursor < line.endIndex, let digit = line[cursor].wholeNumberValue, digit < 10 {
                value = value * 10 + digit
                digitCount += 1
                cursor = line.index(after: cursor)
            }
            guard cursor < line.endIndex else { return nil }
            let delim = line[cursor]
            guard delim == "." || delim == ")" else { return nil }
            markerDelim = delim
            markerWidth = digitCount + 1
            ordered = true
            orderedValue = value
            cursor = line.index(after: cursor)
        } else {
            return nil
        }

        guard cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" else {
            return nil
        }
        var spacesAfter = 0
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            spacesAfter += 1
            cursor = line.index(after: cursor)
        }

        return RawItem(
            markerColumn: indent + 1,
            markerWidth: markerWidth,
            markerDelim: markerDelim,
            ordered: ordered,
            orderedValue: orderedValue,
            spacesAfter: spacesAfter
        )
    }

    private static func splitLines(_ content: String) -> [String] {
        var lines = content.components(separatedBy: .newlines)
        if content.hasSuffix("\n"), lines.last == "" {
            lines.removeLast()
        }
        return lines
    }
}

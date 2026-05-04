import Foundation

/// Per-column alignment specified by the delimiter row.
public enum TableColumnAlignment: Sendable, Equatable {
    case none
    case left
    case right
    case center
}

/// One row of a GFM table — header, delimiter, or body.
public struct TableRow: Sendable, Equatable {
    /// 1-indexed source line.
    public let line: Int
    /// The raw line, without trailing newline.
    public let raw: String
    /// True when the line starts with a `|` (after optional 0–3 spaces of indent).
    public let hasLeadingPipe: Bool
    /// True when the line ends with a `|` (before any trailing whitespace).
    public let hasTrailingPipe: Bool
    /// Character offsets of every (unescaped) `|` in `raw`, in source order.
    public let pipePositions: [Int]
    /// Cell strings, in source order. Each is the raw substring between pipes — unstripped of
    /// leading/trailing whitespace, so style rules can inspect padding.
    public let cells: [String]

    public init(
        line: Int,
        raw: String,
        hasLeadingPipe: Bool,
        hasTrailingPipe: Bool,
        pipePositions: [Int],
        cells: [String]
    ) {
        self.line = line
        self.raw = raw
        self.hasLeadingPipe = hasLeadingPipe
        self.hasTrailingPipe = hasTrailingPipe
        self.pipePositions = pipePositions
        self.cells = cells
    }
}

/// A GFM table.
public struct Table: Sendable, Equatable {
    /// 1-indexed first line of the table (the header row).
    public let startLine: Int
    /// 1-indexed last line of the table (last body row, or delimiter row when no body).
    public let endLine: Int
    public let header: TableRow
    public let delimiter: TableRow
    public let alignments: [TableColumnAlignment]
    public let body: [TableRow]

    public init(
        startLine: Int,
        endLine: Int,
        header: TableRow,
        delimiter: TableRow,
        alignments: [TableColumnAlignment],
        body: [TableRow]
    ) {
        self.startLine = startLine
        self.endLine = endLine
        self.header = header
        self.delimiter = delimiter
        self.alignments = alignments
        self.body = body
    }

    /// All rows in source order — header, then delimiter, then body.
    public var allRows: [TableRow] { [header, delimiter] + body }
}

/// GitHub-Flavored-Markdown table tokenizer.
///
/// Recognizes a table as: a non-blank line containing at least one `|` (the header), immediately
/// followed by a delimiter row matching `:?-+:?` per column with optional pipes and whitespace,
/// followed by zero or more body rows. The body terminates at a blank line, a non-pipe line,
/// EOF, or a line that begins a new structural block.
///
/// Lines inside frontmatter, fenced code, or indented code are skipped via `BlockTokenizer`.
public enum TableTokenizer {
    /// Tokenize all GFM tables in `content`. Returns tables in source order.
    public static func tokenize(_ content: String) -> [Table] {
        let rawLines = content.components(separatedBy: .newlines)
        let lines: [String]
        if content.hasSuffix("\n"), rawLines.last == "" {
            lines = Array(rawLines.dropLast())
        } else {
            lines = rawLines
        }
        guard !lines.isEmpty else { return [] }

        let opaqueLines = opaqueLineSet(content: content)

        var tables: [Table] = []
        var index = 0
        while index < lines.count {
            let lineNo = index + 1
            if opaqueLines.contains(lineNo) {
                index += 1
                continue
            }
            let line = lines[index]
            // The header row is `lines[index]` only if `lines[index+1]` is a valid delimiter row
            // for the same column count.
            let headerCells = parseCells(line)
            guard headerCells.cellCount >= 1, headerCells.containsPipe,
                index + 1 < lines.count
            else {
                index += 1
                continue
            }
            let delimLineNo = lineNo + 1
            if opaqueLines.contains(delimLineNo) {
                index += 1
                continue
            }
            let delimLine = lines[index + 1]
            guard let alignments = parseDelimiterAlignments(delimLine),
                alignments.count == headerCells.cellCount
            else {
                index += 1
                continue
            }

            let header = makeRow(line: lineNo, raw: line)
            let delimiter = makeRow(line: delimLineNo, raw: delimLine)

            var body: [TableRow] = []
            var bodyIndex = index + 2
            while bodyIndex < lines.count {
                let bodyLineNo = bodyIndex + 1
                if opaqueLines.contains(bodyLineNo) { break }
                let bodyLine = lines[bodyIndex]
                if isBlank(bodyLine) { break }
                let bodyCells = parseCells(bodyLine)
                guard bodyCells.containsPipe else { break }
                body.append(makeRow(line: bodyLineNo, raw: bodyLine))
                bodyIndex += 1
            }

            let endLine = body.last?.line ?? delimiter.line
            tables.append(
                Table(
                    startLine: lineNo,
                    endLine: endLine,
                    header: header,
                    delimiter: delimiter,
                    alignments: alignments,
                    body: body
                )
            )
            index = bodyIndex
        }
        return tables
    }

    private static func opaqueLineSet(content: String) -> Set<Int> {
        var set: Set<Int> = []
        for block in BlockTokenizer.tokenize(content) {
            switch block.kind {
            case .fencedCode, .indentedCode, .frontmatter:
                for ln in block.startLine...block.endLine { set.insert(ln) }
            default:
                continue
            }
        }
        return set
    }

    /// Split a line on unescaped pipes. Returns the cell texts and a flag indicating whether any
    /// pipe was present at all.
    private static func parseCells(_ line: String) -> (cells: [String], cellCount: Int, containsPipe: Bool) {
        let chars = Array(line)
        var cells: [String] = []
        var current: [Character] = []
        var containsPipe = false
        var hasLeadingPipeOnly = false
        var i = 0
        // Strip up to 3 spaces of indent for cell-extraction purposes; the indent doesn't change
        // semantics but it shouldn't appear in the first cell.
        var leadingSpaces = 0
        while i < chars.count, chars[i] == " ", leadingSpaces < 3 {
            i += 1
            leadingSpaces += 1
        }
        // If the very first non-indent char is `|`, that's the leading pipe — don't emit an
        // empty cell before it.
        if i < chars.count, chars[i] == "|", !InlineTokenizer.isEscaped(chars: chars, at: i) {
            hasLeadingPipeOnly = true
            containsPipe = true
            i += 1
        }
        while i < chars.count {
            if chars[i] == "|", !InlineTokenizer.isEscaped(chars: chars, at: i) {
                cells.append(String(current))
                current = []
                containsPipe = true
                i += 1
                continue
            }
            current.append(chars[i])
            i += 1
        }
        // Decide what to do with `current`. If the line ends with a trailing pipe, `current` is
        // the (possibly whitespace) trailing content after the last `|`; ignore it. Otherwise
        // it's the final cell.
        let trimmedTail = String(current).trimmingCharacters(in: .whitespaces)
        if trimmedTail.isEmpty, containsPipe {
            // Trailing pipe — `current` is whitespace after the last `|`.
        } else {
            cells.append(String(current))
        }
        _ = hasLeadingPipeOnly
        return (cells, cells.count, containsPipe)
    }

    private static func makeRow(line: Int, raw: String) -> TableRow {
        let chars = Array(raw)
        var pipePositions: [Int] = []
        for (i, ch) in chars.enumerated() where ch == "|" {
            if InlineTokenizer.isEscaped(chars: chars, at: i) { continue }
            pipePositions.append(i)
        }
        let leadingNonWS = firstNonWhitespaceIndex(chars: chars)
        let hasLeadingPipe = leadingNonWS.map { chars[$0] == "|" } ?? false
        let trailingNonWS = lastNonWhitespaceIndex(chars: chars)
        let hasTrailingPipe = trailingNonWS.map { chars[$0] == "|" } ?? false
        let cells = parseCells(raw).cells
        return TableRow(
            line: line,
            raw: raw,
            hasLeadingPipe: hasLeadingPipe,
            hasTrailingPipe: hasTrailingPipe,
            pipePositions: pipePositions,
            cells: cells
        )
    }

    private static func firstNonWhitespaceIndex(chars: [Character]) -> Int? {
        for (i, ch) in chars.enumerated() where ch != " " && ch != "\t" { return i }
        return nil
    }

    private static func lastNonWhitespaceIndex(chars: [Character]) -> Int? {
        var i = chars.count - 1
        while i >= 0 {
            let ch = chars[i]
            if ch != " " && ch != "\t" { return i }
            i -= 1
        }
        return nil
    }

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Parse a delimiter row into per-column alignments. Returns `nil` when the line is not a
    /// valid delimiter row.
    static func parseDelimiterAlignments(_ line: String) -> [TableColumnAlignment]? {
        // A delimiter line consists of optional indent, optional leading `|`, one or more
        // segments separated by `|`, and optional trailing `|`. Each segment is whitespace,
        // optional `:`, one or more `-`, optional `:`, whitespace.
        let chars = Array(line)
        var i = 0
        var indent = 0
        while i < chars.count, chars[i] == " ", indent < 3 {
            i += 1
            indent += 1
        }
        guard i < chars.count else { return nil }
        if chars[i] == "|" { i += 1 }
        var alignments: [TableColumnAlignment] = []
        while i < chars.count {
            // skip whitespace
            while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
            // optional leading colon
            var leftColon = false
            if i < chars.count, chars[i] == ":" {
                leftColon = true
                i += 1
            }
            // one or more dashes
            var dashCount = 0
            while i < chars.count, chars[i] == "-" {
                dashCount += 1
                i += 1
            }
            guard dashCount >= 1 else { return nil }
            // optional trailing colon
            var rightColon = false
            if i < chars.count, chars[i] == ":" {
                rightColon = true
                i += 1
            }
            // skip whitespace
            while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
            alignments.append(alignmentFor(left: leftColon, right: rightColon))
            if i >= chars.count { break }
            if chars[i] == "|" {
                i += 1
                // After a `|`, allow trailing whitespace then EOL — that's a trailing pipe.
                var tail = i
                while tail < chars.count, chars[tail] == " " || chars[tail] == "\t" { tail += 1 }
                if tail >= chars.count {
                    i = chars.count
                    break
                }
                continue
            }
            // Anything else → invalid delimiter.
            return nil
        }
        return alignments.isEmpty ? nil : alignments
    }

    private static func alignmentFor(left: Bool, right: Bool) -> TableColumnAlignment {
        switch (left, right) {
        case (false, false): return .none
        case (true, false): return .left
        case (false, true): return .right
        case (true, true): return .center
        }
    }
}

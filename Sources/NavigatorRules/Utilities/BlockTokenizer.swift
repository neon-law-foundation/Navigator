import Foundation

/// Heading style used by a given ATX or setext heading.
public enum HeadingStyle: Sendable, Equatable {
    /// `# Heading`
    case atx
    /// `# Heading #`
    case atxClosed
    /// Setext — a line of text followed by `===` (h1) or `---` (h2).
    case setext
}

/// The marker used by a fenced code block — backtick or tilde.
public enum FenceMarker: Sendable, Equatable {
    case backtick
    case tilde
}

/// The kind of a block returned by `BlockTokenizer`.
public enum BlockKind: Sendable, Equatable {
    /// A single heading.
    case heading(level: Int, style: HeadingStyle, text: String)
    /// A horizontal rule (`---`, `***`, `___`).
    case hr
    /// A fenced code block. `startLine`/`endLine` include the opening and closing fence lines.
    case fencedCode(marker: FenceMarker, info: String)
    /// A run of 4-space-indented (or tab-indented) code lines separated from paragraphs by a blank.
    case indentedCode
    /// A run of consecutive block-quote lines (`> …`) with no intervening blanks.
    case blockquote
    /// A run of consecutive list items with no intervening blanks.
    case list(marker: Character, ordered: Bool)
    /// One or more non-heading, non-code paragraph lines.
    case paragraph
    /// One or more consecutive blank lines.
    case blank
    /// The top-level YAML frontmatter block, including the `---` fences.
    case frontmatter
}

/// A span of lines classified into one `BlockKind`.
public struct Block: Sendable, Equatable {
    public let kind: BlockKind
    /// 1-indexed inclusive start line.
    public let startLine: Int
    /// 1-indexed inclusive end line.
    public let endLine: Int

    public init(kind: BlockKind, startLine: Int, endLine: Int) {
        self.kind = kind
        self.startLine = startLine
        self.endLine = endLine
    }
}

/// Block-level tokenizer. Splits a markdown file into a sequence of `Block`s covering every line.
///
/// Phase-2 granularity: heading (ATX/setext), hr, fenced code, indented code, blockquote, list,
/// paragraph, blank, and YAML frontmatter. Not a full CommonMark parser — suitable for the ten
/// block-level rules ported in Phase 2 of #97.
public enum BlockTokenizer {
    /// Tokenize `content` into blocks. The returned blocks cover every line in order; every
    /// 1-indexed line number appears in exactly one block.
    public static func tokenize(_ content: String) -> [Block] {
        guard !content.isEmpty else { return [] }
        let rawLines = content.components(separatedBy: .newlines)
        // A trailing `\n` leaves an empty final element; drop it so it doesn't get its own blank block.
        let lines: [String]
        if content.hasSuffix("\n"), rawLines.last == "" {
            lines = Array(rawLines.dropLast())
        } else {
            lines = rawLines
        }
        guard !lines.isEmpty else { return [] }

        var blocks: [Block] = []
        var index = 0

        // Optional YAML frontmatter at the top.
        if let end = frontmatterEnd(in: lines) {
            blocks.append(Block(kind: .frontmatter, startLine: 1, endLine: end + 1))
            index = end + 1
        }

        while index < lines.count {
            let line = lines[index]
            let lineNo = index + 1

            if isBlank(line) {
                let end = advanceWhile(lines: lines, from: index) { isBlank($0) }
                blocks.append(Block(kind: .blank, startLine: lineNo, endLine: end))
                index = end
                continue
            }

            if let fence = parseFenceOpen(line) {
                let (endIndex, endLine) = consumeFencedCode(
                    lines: lines,
                    openIndex: index,
                    marker: fence.marker
                )
                blocks.append(
                    Block(
                        kind: .fencedCode(marker: fence.marker, info: fence.info),
                        startLine: lineNo,
                        endLine: endLine
                    )
                )
                index = endIndex
                continue
            }

            if isATXHeading(line) {
                let (level, style, text) = parseATXHeading(line)
                blocks.append(
                    Block(
                        kind: .heading(level: level, style: style, text: text),
                        startLine: lineNo,
                        endLine: lineNo
                    )
                )
                index += 1
                continue
            }

            if isHorizontalRule(line) {
                blocks.append(Block(kind: .hr, startLine: lineNo, endLine: lineNo))
                index += 1
                continue
            }

            if isBlockquoteLine(line) {
                let end = advanceWhile(lines: lines, from: index) { isBlockquoteLine($0) }
                blocks.append(Block(kind: .blockquote, startLine: lineNo, endLine: end))
                index = end
                continue
            }

            if let listInfo = parseListItemStart(line) {
                // A list extends while the next line is another list item or an
                // indented continuation (starts with whitespace). Any flush-left
                // non-list line ends the visual list for M032 style purposes.
                var end = index + 1
                while end < lines.count {
                    let candidate = lines[end]
                    if isBlank(candidate) { break }
                    if parseListItemStart(candidate) != nil {
                        end += 1
                        continue
                    }
                    let startsWithWhitespace =
                        candidate.first == " " || candidate.first == "\t"
                    if startsWithWhitespace {
                        end += 1
                        continue
                    }
                    break
                }
                blocks.append(
                    Block(
                        kind: .list(marker: listInfo.marker, ordered: listInfo.ordered),
                        startLine: lineNo,
                        endLine: end
                    )
                )
                index = end
                continue
            }

            if isIndentedCode(line), canStartIndentedCode(at: index, lines: lines) {
                let end = advanceWhile(lines: lines, from: index) {
                    isIndentedCode($0) || isBlank($0)
                }
                // Trim trailing blank lines back out of the indented-code block; they belong to
                // the following blank block.
                var trimmed = end
                while trimmed > index, isBlank(lines[trimmed - 1]) {
                    trimmed -= 1
                }
                blocks.append(Block(kind: .indentedCode, startLine: lineNo, endLine: trimmed))
                index = trimmed
                continue
            }

            // Paragraph: accumulate lines until a blank / heading / hr / fence / blockquote / list.
            let paragraphEnd = advanceWhile(lines: lines, from: index) { candidate in
                !isBlank(candidate) && !isATXHeading(candidate) && !isHorizontalRule(candidate)
                    && parseFenceOpen(candidate) == nil && !isBlockquoteLine(candidate)
                    && parseListItemStart(candidate) == nil && !isSetextUnderline(candidate)
            }

            // Check for a setext underline immediately after the paragraph.
            if paragraphEnd < lines.count,
                let setextLevel = setextLevel(of: lines[paragraphEnd])
            {
                let text = lines[index..<paragraphEnd].joined(separator: "\n")
                    .trimmingCharacters(in: .whitespaces)
                blocks.append(
                    Block(
                        kind: .heading(level: setextLevel, style: .setext, text: text),
                        startLine: lineNo,
                        endLine: paragraphEnd + 1
                    )
                )
                index = paragraphEnd + 1
                continue
            }

            blocks.append(Block(kind: .paragraph, startLine: lineNo, endLine: paragraphEnd))
            index = paragraphEnd
        }

        return blocks
    }

    // MARK: - Line predicates

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func isATXHeading(_ line: String) -> Bool {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex, line[cursor] == "#" else { return false }
        var hashes = 0
        while cursor < line.endIndex, line[cursor] == "#" {
            cursor = line.index(after: cursor)
            hashes += 1
        }
        guard (1...6).contains(hashes) else { return false }
        // Either end-of-line or whitespace after the hashes qualifies.
        if cursor == line.endIndex { return true }
        return line[cursor].isWhitespace
    }

    private static func parseATXHeading(_ line: String) -> (level: Int, style: HeadingStyle, text: String) {
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor] == " " { cursor = line.index(after: cursor) }
        var level = 0
        while cursor < line.endIndex, line[cursor] == "#" {
            cursor = line.index(after: cursor)
            level += 1
        }
        let afterOpening = line[cursor...]
        // Strip trailing closing hashes (with preceding whitespace) for atxClosed detection.
        var text = String(afterOpening).trimmingCharacters(in: .whitespaces)
        var style: HeadingStyle = .atx
        if !text.isEmpty {
            // Detect closing hashes preceded by whitespace in the original line.
            // Work on the raw trimmed-right line for a stable check.
            let trimmedRight = String(afterOpening).reversed().drop(while: { $0 == " " || $0 == "\t" })
            if trimmedRight.first == "#" {
                let reversed = Array(trimmedRight)
                var i = 0
                while i < reversed.count, reversed[i] == "#" { i += 1 }
                if i < reversed.count, reversed[i].isWhitespace {
                    style = .atxClosed
                    var textChars = Array(afterOpening)
                    // Drop trailing spaces.
                    while let last = textChars.last, last == " " || last == "\t" {
                        textChars.removeLast()
                    }
                    // Drop closing hashes.
                    while let last = textChars.last, last == "#" {
                        textChars.removeLast()
                    }
                    text = String(textChars).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return (level, style, text)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex else { return false }
        let marker = line[cursor]
        guard marker == "-" || marker == "*" || marker == "_" else { return false }
        var count = 0
        while cursor < line.endIndex {
            let ch = line[cursor]
            if ch == marker {
                count += 1
            } else if ch == " " || ch == "\t" {
                // allowed
            } else {
                return false
            }
            cursor = line.index(after: cursor)
        }
        return count >= 3
    }

    private static func isSetextUnderline(_ line: String) -> Bool {
        setextLevel(of: line) != nil
    }

    /// `===` underline → h1, `---` underline → h2.
    private static func setextLevel(of line: String) -> Int? {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex else { return nil }
        let marker = line[cursor]
        guard marker == "=" || marker == "-" else { return nil }
        var count = 0
        while cursor < line.endIndex, line[cursor] == marker {
            cursor = line.index(after: cursor)
            count += 1
        }
        // Allow trailing whitespace only.
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        guard cursor == line.endIndex, count >= 1 else { return nil }
        return marker == "=" ? 1 : 2
    }

    /// Parse an opening fence. Returns `nil` when the line is not a fence open.
    private static func parseFenceOpen(_ line: String) -> (marker: FenceMarker, info: String)? {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex else { return nil }
        let ch = line[cursor]
        let marker: FenceMarker
        switch ch {
        case "`": marker = .backtick
        case "~": marker = .tilde
        default: return nil
        }
        var count = 0
        while cursor < line.endIndex, line[cursor] == ch {
            cursor = line.index(after: cursor)
            count += 1
        }
        guard count >= 3 else { return nil }
        let info = String(line[cursor...]).trimmingCharacters(in: .whitespaces)
        // Backtick fences disallow backticks in the info string; tilde fences are freer.
        if marker == .backtick, info.contains("`") { return nil }
        return (marker, info)
    }

    /// Return true when `line` closes a fenced code block with the given opening marker.
    private static func isFenceClose(_ line: String, marker: FenceMarker) -> Bool {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex else { return false }
        let expected: Character = marker == .backtick ? "`" : "~"
        guard line[cursor] == expected else { return false }
        var count = 0
        while cursor < line.endIndex, line[cursor] == expected {
            cursor = line.index(after: cursor)
            count += 1
        }
        guard count >= 3 else { return false }
        // Trailing whitespace only.
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        return cursor == line.endIndex
    }

    private static func consumeFencedCode(
        lines: [String],
        openIndex: Int,
        marker: FenceMarker
    ) -> (endIndex: Int, endLine: Int) {
        var index = openIndex + 1
        while index < lines.count, !isFenceClose(lines[index], marker: marker) {
            index += 1
        }
        // If we found a close fence, include it; otherwise the block runs to EOF.
        let endIndex = min(index + 1, lines.count)
        return (endIndex, endIndex)
    }

    private static func isBlockquoteLine(_ line: String) -> Bool {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        return cursor < line.endIndex && line[cursor] == ">"
    }

    private static func parseListItemStart(_ line: String) -> (marker: Character, ordered: Bool)? {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex else { return nil }
        let ch = line[cursor]
        if ch == "-" || ch == "*" || ch == "+" {
            let next = line.index(after: cursor)
            guard next < line.endIndex, line[next] == " " || line[next] == "\t" else { return nil }
            return (ch, false)
        }
        // Ordered list: one or more digits, then `.` or `)`, then whitespace.
        var digitEnd = cursor
        while digitEnd < line.endIndex, line[digitEnd].isNumber {
            digitEnd = line.index(after: digitEnd)
        }
        guard digitEnd > cursor, digitEnd < line.endIndex else { return nil }
        let delim = line[digitEnd]
        guard delim == "." || delim == ")" else { return nil }
        let after = line.index(after: digitEnd)
        guard after < line.endIndex, line[after] == " " || line[after] == "\t" else { return nil }
        return (delim, true)
    }

    private static func isIndentedCode(_ line: String) -> Bool {
        if line.hasPrefix("    ") { return true }
        if line.hasPrefix("\t") { return true }
        return false
    }

    /// Indented code blocks can only start when the preceding context is blank (or beginning of file).
    /// If the previous non-blank line was a paragraph, an indented line is paragraph continuation.
    private static func canStartIndentedCode(at index: Int, lines: [String]) -> Bool {
        if index == 0 { return true }
        return isBlank(lines[index - 1])
    }

    private static func advanceWhile(
        lines: [String],
        from index: Int,
        while predicate: (String) -> Bool
    ) -> Int {
        var i = index
        while i < lines.count, predicate(lines[i]) { i += 1 }
        return i
    }

    private static func frontmatterEnd(in lines: [String]) -> Int? {
        guard lines.first == "---" else { return nil }
        for (idx, line) in lines.enumerated() where idx > 0 {
            if line == "---" { return idx }
        }
        return nil
    }
}

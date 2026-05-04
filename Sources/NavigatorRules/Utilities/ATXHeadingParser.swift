import Foundation

/// Shared ATX heading parsing helpers used by M018 / M019 / M020 / M021 / M023.
public enum ATXHeadingParser {
    /// Parsed shape of an ATX heading line.
    public struct Parts {
        /// Leading 0-3 spaces of indent.
        public let indent: String
        /// The run of 1-6 `#` characters that open the heading.
        public let openingHashes: String
        /// Everything between the opening hashes and the (optional) closing hashes / end of line.
        public let middle: String
        /// Optional trailing whitespace + closing hashes (closed ATX). Empty string when absent.
        public let closing: String
    }

    /// Parse `line` as an ATX heading. Returns `nil` when the line is not a heading.
    public static func parse(_ line: String) -> Parts? {
        guard let opening = parseOpening(line) else { return nil }

        let rest = String(line[opening.cursor...])
        let trailing = Self.splitTrailingClose(rest: rest)
        return Parts(
            indent: opening.indent,
            openingHashes: opening.hashes,
            middle: trailing.middle,
            closing: trailing.closing
        )
    }

    /// Split the portion of a line following the opening hashes into `middle` and
    /// the closing run (`" ###"` style) when present.
    private static func splitTrailingClose(rest: String) -> (middle: String, closing: String) {
        // Work from the right: drop trailing spaces/tabs, then the run of closing `#`s, then
        // require a space between the heading text and the closing hashes to treat it as closed.
        var index = rest.endIndex
        while index > rest.startIndex {
            let prev = rest.index(before: index)
            if rest[prev].isWhitespace { index = prev } else { break }
        }
        let afterTrailingWhitespaceEnd = index

        var closingStart = index
        while closingStart > rest.startIndex {
            let prev = rest.index(before: closingStart)
            if rest[prev] == "#" { closingStart = prev } else { break }
        }
        let closingHashCount = rest.distance(from: closingStart, to: afterTrailingWhitespaceEnd)

        guard closingHashCount > 0, closingStart > rest.startIndex else {
            return (rest, "")
        }
        // For a closed ATX heading, the closing hashes must be preceded by whitespace.
        let beforeClosing = rest.index(before: closingStart)
        guard rest[beforeClosing].isWhitespace else {
            return (rest, "")
        }
        let middle = String(rest[..<closingStart])
        let closing = String(rest[closingStart...])
        return (middle, closing)
    }

    /// Returns true when the line is an ATX heading whose opening hashes are not followed by a space.
    public static func missingSpaceAfterHashes(in line: String) -> Bool {
        guard let parts = parse(line) else { return false }
        guard let first = parts.middle.first else { return false }
        return !first.isWhitespace
    }

    /// Insert a single space between the opening hashes and the heading text.
    public static func insertSpaceAfterHashes(in line: String) -> String {
        guard let parts = parse(line) else { return line }
        return parts.indent + parts.openingHashes + " " + parts.middle + parts.closing
    }

    /// Parsed shape of a line that looks like a (possibly malformed) closed ATX heading.
    public struct ClosedParts {
        /// Leading 0-3 spaces of indent.
        public let indent: String
        /// The run of 1-6 `#` characters that open the heading.
        public let openingHashes: String
        /// Everything strictly between the opening and closing hashes, including any padding.
        public let content: String
        /// The run of 1+ `#` characters that close the heading.
        public let closingHashes: String
        /// Optional trailing whitespace after the closing hashes.
        public let trailing: String
    }

    /// Parse `line` as a closed ATX heading, tolerating missing/extra whitespace around the text.
    ///
    /// Returns `nil` for lines that don't have a plausible opening hash run followed by content
    /// and a trailing hash run. Use this for MD020/MD021-style checks where we need to detect
    /// *malformed* closed headings.
    public static func parseClosed(_ line: String) -> ClosedParts? {
        guard let opening = parseOpening(line) else { return nil }
        let cursor = opening.cursor

        // Scan from the right: trailing whitespace then trailing hashes.
        var rightEnd = line.endIndex
        while rightEnd > cursor {
            let prev = line.index(before: rightEnd)
            if line[prev].isWhitespace { rightEnd = prev } else { break }
        }
        let trailing = String(line[rightEnd..<line.endIndex])

        var closingStart = rightEnd
        while closingStart > cursor {
            let prev = line.index(before: closingStart)
            if line[prev] == "#" { closingStart = prev } else { break }
        }
        let closingHashes = String(line[closingStart..<rightEnd])
        guard !closingHashes.isEmpty else { return nil }

        let content = String(line[cursor..<closingStart])
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        guard !trimmedContent.isEmpty, trimmedContent.contains(where: { $0 != "#" }) else {
            return nil
        }

        return ClosedParts(
            indent: opening.indent,
            openingHashes: opening.hashes,
            content: content,
            closingHashes: closingHashes,
            trailing: trailing
        )
    }

    /// Parse the leading 0-3 space indent and 1-6 `#` opening run, returning the cursor
    /// positioned just past the hash run. Returns `nil` when the line doesn't start with hashes.
    private static func parseOpening(
        _ line: String
    )
        -> (indent: String, hashes: String, cursor: String.Index)?
    {
        var cursor = line.startIndex
        var indent = ""
        while cursor < line.endIndex, line[cursor] == " ", indent.count < 3 {
            indent.append(line[cursor])
            cursor = line.index(after: cursor)
        }

        guard cursor < line.endIndex, line[cursor] == "#" else { return nil }

        var hashes = ""
        while cursor < line.endIndex, line[cursor] == "#" {
            hashes.append(line[cursor])
            cursor = line.index(after: cursor)
        }
        guard (1...6).contains(hashes.count) else { return nil }
        return (indent, hashes, cursor)
    }
}

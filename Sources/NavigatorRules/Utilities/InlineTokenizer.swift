import Foundation

/// Inline-level tokenizer used by Phase 4 rules.
///
/// Provides three views over a single line of markdown:
///
/// * `codeSpans(in:)` — backtick-delimited code spans. Other inline rules must treat code spans
///   as opaque: emphasis and link brackets inside them are literal characters.
/// * `emphasisRuns(in:)` — well-formed emphasis/strong spans (`*x*`, `_x_`, `**x**`, `__x__`)
///   following the CommonMark left/right-flanking delimiter rules, with a simplified matcher.
/// * `inlineLinks(in:)` — link and image shapes, including inline, reference, collapsed, and
///   shortcut forms.
///
/// The tokenizer is intentionally line-scoped. Block-level skipping (fenced code, indented code,
/// frontmatter) must be done by the caller via `BlockTokenizer`.
public enum InlineTokenizer {

    // MARK: - Code spans

    /// A single backtick code span.
    public struct CodeSpan: Equatable, Sendable {
        /// Full range of the code span including opening and closing backticks.
        public let range: Range<String.Index>
        /// Range of the content between the fences, excluding the backticks.
        public let contentRange: Range<String.Index>
        /// Number of backticks in the opening/closing fence.
        public let backtickCount: Int

        public init(
            range: Range<String.Index>,
            contentRange: Range<String.Index>,
            backtickCount: Int
        ) {
            self.range = range
            self.contentRange = contentRange
            self.backtickCount = backtickCount
        }
    }

    /// Return the code spans in `line`, in source order.
    ///
    /// A code span is a run of `N` backticks, followed by any content, followed by another run
    /// of exactly `N` backticks. Runs preceded by a backslash are escaped and do not start a
    /// span. Unmatched opening runs are ignored.
    public static func codeSpans(in line: String) -> [CodeSpan] {
        var spans: [CodeSpan] = []
        let runs = backtickRuns(in: line)
        var index = 0
        while index < runs.count {
            let opener = runs[index]
            if opener.escaped {
                index += 1
                continue
            }
            var matched = false
            var j = index + 1
            while j < runs.count {
                let candidate = runs[j]
                if !candidate.escaped, candidate.length == opener.length {
                    let full = opener.range.lowerBound..<candidate.range.upperBound
                    let content = opener.range.upperBound..<candidate.range.lowerBound
                    spans.append(
                        CodeSpan(range: full, contentRange: content, backtickCount: opener.length)
                    )
                    index = j + 1
                    matched = true
                    break
                }
                j += 1
            }
            if !matched {
                index += 1
            }
        }
        return spans
    }

    /// True when `index` lies strictly inside any code span in `spans`.
    public static func isInCodeSpan(_ index: String.Index, spans: [CodeSpan]) -> Bool {
        for span in spans where span.range.contains(index) { return true }
        return false
    }

    /// Integer character-offset set of every position inside any code span on `line`.
    ///
    /// Rules that work in `[Character]` space (for random-access index math) use this to
    /// cheaply test whether a position falls inside a backtick-delimited span.
    public static func codeSpanCharIndexes(line: String, spans: [CodeSpan]) -> Set<Int> {
        var set: Set<Int> = []
        for span in spans {
            let start = line.distance(from: line.startIndex, to: span.range.lowerBound)
            let end = line.distance(from: line.startIndex, to: span.range.upperBound)
            for i in start..<end { set.insert(i) }
        }
        return set
    }

    private struct BacktickRun {
        let range: Range<String.Index>
        let length: Int
        let escaped: Bool
    }

    private static func backtickRuns(in line: String) -> [BacktickRun] {
        var runs: [BacktickRun] = []
        var cursor = line.startIndex
        while cursor < line.endIndex {
            if line[cursor] == "`" {
                // Determine if this run is escaped by a preceding backslash. A backslash escapes
                // the character that follows, but `\\` itself is an escaped backslash, so we
                // count *consecutive* trailing backslashes; an odd count means this backtick is
                // escaped.
                var backslashes = 0
                var probe = cursor
                while probe > line.startIndex {
                    let prev = line.index(before: probe)
                    if line[prev] == "\\" {
                        backslashes += 1
                        probe = prev
                    } else {
                        break
                    }
                }
                let escaped = backslashes % 2 == 1
                let start = cursor
                var length = 0
                while cursor < line.endIndex, line[cursor] == "`" {
                    length += 1
                    cursor = line.index(after: cursor)
                }
                runs.append(
                    BacktickRun(
                        range: start..<cursor,
                        length: length,
                        escaped: escaped
                    )
                )
                continue
            }
            cursor = line.index(after: cursor)
        }
        return runs
    }

    // MARK: - Emphasis / strong

    /// A well-formed emphasis or strong run — `*x*`, `_x_`, `**x**`, `__x__`.
    public struct EmphasisRun: Equatable, Sendable {
        public let marker: Character
        public let count: Int
        public let openerRange: Range<String.Index>
        public let closerRange: Range<String.Index>
        public let contentRange: Range<String.Index>

        public init(
            marker: Character,
            count: Int,
            openerRange: Range<String.Index>,
            closerRange: Range<String.Index>,
            contentRange: Range<String.Index>
        ) {
            self.marker = marker
            self.count = count
            self.openerRange = openerRange
            self.closerRange = closerRange
            self.contentRange = contentRange
        }
    }

    /// Parse the emphasis and strong runs in `line`, skipping content inside code spans.
    ///
    /// The matcher mirrors CommonMark's left-flanking / right-flanking delimiter rules
    /// sufficiently for stylistic linting: a `*` run is allowed to break words; a `_` run is
    /// not (intraword emphasis with `_` is disabled in GFM-style markdown). Runs are greedily
    /// paired left-to-right; strong is preferred over emphasis when a run is at least length 2.
    public static func emphasisRuns(in line: String) -> [EmphasisRun] {
        let spans = codeSpans(in: line)
        let delimiters = delimiterRuns(in: line, codeSpans: spans)
        return matchEmphasis(delimiters: delimiters, line: line)
    }

    private struct DelimiterRun {
        var range: Range<String.Index>
        var marker: Character
        var length: Int
        var canOpen: Bool
        var canClose: Bool
    }

    private static func delimiterRuns(
        in line: String,
        codeSpans: [CodeSpan]
    ) -> [DelimiterRun] {
        var runs: [DelimiterRun] = []
        var cursor = line.startIndex
        while cursor < line.endIndex {
            let ch = line[cursor]
            if ch != "*" && ch != "_" {
                cursor = line.index(after: cursor)
                continue
            }
            if isInCodeSpan(cursor, spans: codeSpans) {
                cursor = line.index(after: cursor)
                continue
            }
            if isEscaped(line: line, at: cursor) {
                cursor = line.index(after: cursor)
                continue
            }
            let start = cursor
            var length = 0
            while cursor < line.endIndex, line[cursor] == ch {
                length += 1
                cursor = line.index(after: cursor)
            }
            let range = start..<cursor

            let before = charBefore(line: line, index: range.lowerBound)
            let after = charAt(line: line, index: range.upperBound)

            let precededByWhitespace = before.map { $0.isWhitespace } ?? true
            let followedByWhitespace = after.map { $0.isWhitespace } ?? true
            let precededByPunct = before.map { isPunctuation($0) } ?? false
            let followedByPunct = after.map { isPunctuation($0) } ?? false

            let leftFlanking =
                !followedByWhitespace
                && (!followedByPunct || precededByWhitespace || precededByPunct)
            let rightFlanking =
                !precededByWhitespace
                && (!precededByPunct || followedByWhitespace || followedByPunct)

            var canOpen = leftFlanking
            var canClose = rightFlanking
            if ch == "_" {
                // Underscore cannot create intraword emphasis.
                if leftFlanking, rightFlanking {
                    // Must be preceded by whitespace/punct or followed by whitespace/punct to open/close.
                    canOpen = !precededByAlphaNum(line: line, before: before)
                    canClose = !followedByAlphaNum(after: after)
                }
            }

            runs.append(
                DelimiterRun(
                    range: range,
                    marker: ch,
                    length: length,
                    canOpen: canOpen,
                    canClose: canClose
                )
            )
        }
        return runs
    }

    private static func precededByAlphaNum(line: String, before: Character?) -> Bool {
        guard let ch = before else { return false }
        return ch.isLetter || ch.isNumber
    }

    private static func followedByAlphaNum(after: Character?) -> Bool {
        guard let ch = after else { return false }
        return ch.isLetter || ch.isNumber
    }

    private static func isPunctuation(_ ch: Character) -> Bool {
        if ch.isPunctuation { return true }
        if ch.isSymbol { return true }
        return false
    }

    private static func matchEmphasis(
        delimiters: [DelimiterRun],
        line: String
    ) -> [EmphasisRun] {
        var stack: [DelimiterRun] = []
        var results: [EmphasisRun] = []

        for raw in delimiters {
            var current = raw
            while current.length > 0, current.canClose,
                let openerIndex = lastOpenerIndex(stack: stack, marker: current.marker)
            {
                var opener = stack[openerIndex]
                let use = min(opener.length, current.length) >= 2 ? 2 : 1
                if opener.length >= use, current.length >= use {
                    let openerEndOffset = opener.length - use
                    let closerStartOffset = use
                    let openerEnd = line.index(opener.range.lowerBound, offsetBy: use)
                    let closerStart = current.range.lowerBound
                    let closerEnd = line.index(closerStart, offsetBy: use)
                    let openerRange = opener.range.lowerBound..<openerEnd
                    let closerRange = closerStart..<closerEnd
                    let contentRange = openerEnd..<closerStart
                    results.append(
                        EmphasisRun(
                            marker: current.marker,
                            count: use,
                            openerRange: openerRange,
                            closerRange: closerRange,
                            contentRange: contentRange
                        )
                    )
                    let newOpenerEnd = line.index(
                        opener.range.lowerBound,
                        offsetBy: openerEndOffset
                    )
                    opener.range = opener.range.lowerBound..<newOpenerEnd
                    opener.length -= use
                    let newCloserStart = line.index(
                        current.range.lowerBound,
                        offsetBy: closerStartOffset
                    )
                    current.range = newCloserStart..<current.range.upperBound
                    current.length -= use

                    if opener.length == 0 {
                        stack.remove(at: openerIndex)
                    } else {
                        stack[openerIndex] = opener
                        // Pop everything after this opener — CommonMark's "rule of 3" simplified.
                        if stack.count > openerIndex + 1 {
                            stack.removeLast(stack.count - (openerIndex + 1))
                        }
                    }
                } else {
                    break
                }
            }
            if current.length > 0, current.canOpen {
                stack.append(current)
            }
        }
        return results.sorted { $0.openerRange.lowerBound < $1.openerRange.lowerBound }
    }

    private static func lastOpenerIndex(
        stack: [DelimiterRun],
        marker: Character
    ) -> Int? {
        var i = stack.count - 1
        while i >= 0 {
            if stack[i].marker == marker, stack[i].canOpen { return i }
            i -= 1
        }
        return nil
    }

    // MARK: - Links / images

    /// The syntactic shape of a link or image.
    public enum LinkKind: Equatable, Sendable {
        /// `[text](url)` or `![alt](url)`.
        case inline
        /// `[text][label]` or `![alt][label]`.
        case reference
        /// `[label][]` or `![label][]`.
        case collapsed
        /// `[label]` or `![label]`. Only recognized when the label resolves to a known definition.
        case shortcut
    }

    /// A link or image recognized in a line.
    public struct InlineLink: Equatable, Sendable {
        public let kind: LinkKind
        public let isImage: Bool
        /// Full source range including brackets, bang, and destination/label.
        public let fullRange: Range<String.Index>
        /// Range of the text inside the square brackets (the `[ … ]` contents).
        public let textRange: Range<String.Index>
        /// Range of the destination (URL) for inline links, or `nil` otherwise.
        public let destinationRange: Range<String.Index>?
        /// Range of the reference label for reference/collapsed/shortcut links, or `nil` otherwise.
        public let labelRange: Range<String.Index>?
        /// True when the text portion has a leading space.
        public let textHasLeadingSpace: Bool
        /// True when the text portion has a trailing space.
        public let textHasTrailingSpace: Bool

        public init(
            kind: LinkKind,
            isImage: Bool,
            fullRange: Range<String.Index>,
            textRange: Range<String.Index>,
            destinationRange: Range<String.Index>?,
            labelRange: Range<String.Index>?,
            textHasLeadingSpace: Bool,
            textHasTrailingSpace: Bool
        ) {
            self.kind = kind
            self.isImage = isImage
            self.fullRange = fullRange
            self.textRange = textRange
            self.destinationRange = destinationRange
            self.labelRange = labelRange
            self.textHasLeadingSpace = textHasLeadingSpace
            self.textHasTrailingSpace = textHasTrailingSpace
        }
    }

    /// Enumerate links and images in `line`.
    ///
    /// `knownLabels` is the set of normalized reference labels with definitions. A shortcut or
    /// collapsed reference is only emitted when its label resolves against this set — otherwise
    /// the brackets are a literal string. Callers that only need link SHAPE (including unresolved
    /// shortcuts) can pass an empty set.
    public static func inlineLinks(
        in line: String,
        knownLabels: Set<String> = []
    ) -> [InlineLink] {
        let spans = codeSpans(in: line)
        var links: [InlineLink] = []
        var cursor = line.startIndex
        while cursor < line.endIndex {
            if isInCodeSpan(cursor, spans: spans) {
                cursor = line.index(after: cursor)
                continue
            }
            let ch = line[cursor]
            var isImage = false
            var start = cursor
            if ch == "!" {
                let next = line.index(after: cursor)
                if next < line.endIndex, line[next] == "[" {
                    isImage = true
                    start = cursor
                    cursor = next
                } else {
                    cursor = next
                    continue
                }
            }
            guard line[cursor] == "[" else {
                cursor = line.index(after: cursor)
                continue
            }
            if isEscaped(line: line, at: cursor) {
                cursor = line.index(after: cursor)
                continue
            }

            guard
                let textClose = matchingBracket(
                    line: line,
                    from: cursor,
                    open: "[",
                    close: "]",
                    codeSpans: spans
                )
            else {
                cursor = line.index(after: cursor)
                continue
            }
            let textContentRange = line.index(after: cursor)..<textClose

            let afterText = line.index(after: textClose)
            if afterText < line.endIndex, line[afterText] == "(" {
                if let close = matchingBracket(
                    line: line,
                    from: afterText,
                    open: "(",
                    close: ")",
                    codeSpans: spans
                ) {
                    let destRange = line.index(after: afterText)..<close
                    let fullRange = start..<line.index(after: close)
                    let leading = hasLeadingSpace(line: line, range: textContentRange)
                    let trailing = hasTrailingSpace(line: line, range: textContentRange)
                    links.append(
                        InlineLink(
                            kind: .inline,
                            isImage: isImage,
                            fullRange: fullRange,
                            textRange: textContentRange,
                            destinationRange: destRange,
                            labelRange: nil,
                            textHasLeadingSpace: leading,
                            textHasTrailingSpace: trailing
                        )
                    )
                    cursor = line.index(after: close)
                    continue
                }
                cursor = line.index(after: textClose)
                continue
            }
            if afterText < line.endIndex, line[afterText] == "[" {
                if let labelClose = matchingBracket(
                    line: line,
                    from: afterText,
                    open: "[",
                    close: "]",
                    codeSpans: spans
                ) {
                    let labelContentRange = line.index(after: afterText)..<labelClose
                    let leading = hasLeadingSpace(line: line, range: textContentRange)
                    let trailing = hasTrailingSpace(line: line, range: textContentRange)
                    let fullRange = start..<line.index(after: labelClose)
                    let labelText = String(line[labelContentRange]).trimmingCharacters(
                        in: .whitespaces
                    )
                    if labelText.isEmpty {
                        links.append(
                            InlineLink(
                                kind: .collapsed,
                                isImage: isImage,
                                fullRange: fullRange,
                                textRange: textContentRange,
                                destinationRange: nil,
                                labelRange: labelContentRange,
                                textHasLeadingSpace: leading,
                                textHasTrailingSpace: trailing
                            )
                        )
                    } else {
                        // Full reference: `[text][label]`.
                        links.append(
                            InlineLink(
                                kind: .reference,
                                isImage: isImage,
                                fullRange: fullRange,
                                textRange: textContentRange,
                                destinationRange: nil,
                                labelRange: labelContentRange,
                                textHasLeadingSpace: leading,
                                textHasTrailingSpace: trailing
                            )
                        )
                    }
                    cursor = line.index(after: labelClose)
                    continue
                }
                cursor = line.index(after: textClose)
                continue
            }

            // Shortcut reference: `[label]` when label resolves.
            let leading = hasLeadingSpace(line: line, range: textContentRange)
            let trailing = hasTrailingSpace(line: line, range: textContentRange)
            let textLabel = normalizeLabel(String(line[textContentRange]))
            if !textLabel.isEmpty, knownLabels.contains(textLabel) {
                let fullRange = start..<line.index(after: textClose)
                links.append(
                    InlineLink(
                        kind: .shortcut,
                        isImage: isImage,
                        fullRange: fullRange,
                        textRange: textContentRange,
                        destinationRange: nil,
                        labelRange: textContentRange,
                        textHasLeadingSpace: leading,
                        textHasTrailingSpace: trailing
                    )
                )
                cursor = line.index(after: textClose)
                continue
            }
            cursor = line.index(after: textClose)
        }
        return links
    }

    /// Strip inline markup from `text` so the visible text remains.
    ///
    /// Backticks around code spans are removed (their content is preserved verbatim), emphasis
    /// and strong markers around well-formed runs are removed, and link/image syntax collapses
    /// to its visible text (`[text](url)` → `text`, `![alt](url)` → `alt`). Intraword `_`
    /// (e.g. `foo_bar`) does not form a delimiter and is kept.
    public static func stripInlineMarkup(_ text: String) -> String {
        let codeSpans = codeSpans(in: text)
        let emphasis = emphasisRuns(in: text)
        let links = inlineLinks(in: text)

        var dropIndexes = Set<Int>()
        var replaceWithText: [(Range<Int>, String)] = []

        for span in codeSpans {
            let start = text.distance(from: text.startIndex, to: span.range.lowerBound)
            let contentStart = text.distance(from: text.startIndex, to: span.contentRange.lowerBound)
            let contentEnd = text.distance(from: text.startIndex, to: span.contentRange.upperBound)
            let end = text.distance(from: text.startIndex, to: span.range.upperBound)
            for i in start..<contentStart { dropIndexes.insert(i) }
            for i in contentEnd..<end { dropIndexes.insert(i) }
        }

        for run in emphasis {
            let openerStart = text.distance(from: text.startIndex, to: run.openerRange.lowerBound)
            let openerEnd = text.distance(from: text.startIndex, to: run.openerRange.upperBound)
            let closerStart = text.distance(from: text.startIndex, to: run.closerRange.lowerBound)
            let closerEnd = text.distance(from: text.startIndex, to: run.closerRange.upperBound)
            for i in openerStart..<openerEnd { dropIndexes.insert(i) }
            for i in closerStart..<closerEnd { dropIndexes.insert(i) }
        }

        for link in links {
            let fullStart = text.distance(from: text.startIndex, to: link.fullRange.lowerBound)
            let fullEnd = text.distance(from: text.startIndex, to: link.fullRange.upperBound)
            let linkText = String(text[link.textRange])
            replaceWithText.append((fullStart..<fullEnd, linkText))
        }

        let chars = Array(text)
        var output = ""
        var i = 0
        let sortedReplacements = replaceWithText.sorted { $0.0.lowerBound < $1.0.lowerBound }
        var repIndex = 0
        while i < chars.count {
            if repIndex < sortedReplacements.count,
                sortedReplacements[repIndex].0.lowerBound == i
            {
                output.append(sortedReplacements[repIndex].1)
                i = sortedReplacements[repIndex].0.upperBound
                repIndex += 1
                continue
            }
            if dropIndexes.contains(i) {
                i += 1
                continue
            }
            output.append(chars[i])
            i += 1
        }
        return output
    }

    /// Normalize a reference label per CommonMark: Unicode case-fold, collapse internal whitespace,
    /// strip leading/trailing whitespace. CommonMark's full algorithm also does Unicode case
    /// folding; `lowercased()` is a reasonable approximation for ASCII and most Latin labels.
    public static func normalizeLabel(_ raw: String) -> String {
        let collapsed = raw.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.lowercased()
    }

    /// Return the index of the matching closing bracket for the opening bracket at `from`,
    /// tracking nesting and skipping code spans. Returns `nil` when no match exists on this line.
    public static func matchingBracket(
        line: String,
        from: String.Index,
        open: Character,
        close: Character,
        codeSpans: [CodeSpan]
    ) -> String.Index? {
        guard from < line.endIndex, line[from] == open else { return nil }
        var depth = 0
        var cursor = from
        while cursor < line.endIndex {
            if isInCodeSpan(cursor, spans: codeSpans) {
                cursor = line.index(after: cursor)
                continue
            }
            let ch = line[cursor]
            if isEscaped(line: line, at: cursor) {
                cursor = line.index(after: cursor)
                continue
            }
            if ch == open {
                depth += 1
            } else if ch == close {
                depth -= 1
                if depth == 0 { return cursor }
            }
            cursor = line.index(after: cursor)
        }
        return nil
    }

    /// True when the character at `index` is preceded by an odd number of backslashes.
    public static func isEscaped(line: String, at index: String.Index) -> Bool {
        var count = 0
        var cursor = index
        while cursor > line.startIndex {
            let prev = line.index(before: cursor)
            if line[prev] == "\\" {
                count += 1
                cursor = prev
            } else {
                break
            }
        }
        return count % 2 == 1
    }

    /// True when the character at offset `index` in `chars` is preceded by an odd number of
    /// backslashes. `[Character]`-based overload for rules that materialize the line array
    /// for index math.
    public static func isEscaped(chars: [Character], at index: Int) -> Bool {
        var count = 0
        var i = index - 1
        while i >= 0, chars[i] == "\\" {
            count += 1
            i -= 1
        }
        return count % 2 == 1
    }

    // MARK: - Private helpers

    private static func charBefore(line: String, index: String.Index) -> Character? {
        guard index > line.startIndex else { return nil }
        return line[line.index(before: index)]
    }

    private static func charAt(line: String, index: String.Index) -> Character? {
        guard index < line.endIndex else { return nil }
        return line[index]
    }

    private static func hasLeadingSpace(line: String, range: Range<String.Index>) -> Bool {
        guard range.lowerBound < range.upperBound else { return false }
        let first = line[range.lowerBound]
        return first == " " || first == "\t"
    }

    private static func hasTrailingSpace(line: String, range: Range<String.Index>) -> Bool {
        guard range.lowerBound < range.upperBound else { return false }
        let last = line[line.index(before: range.upperBound)]
        return last == " " || last == "\t"
    }
}

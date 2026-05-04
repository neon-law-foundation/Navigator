import Foundation

/// Gathers reference-link definitions and reference-link uses from a markdown document.
///
/// A reference-link definition looks like `[label]: url "optional title"` at the start of a
/// line (preceded by 0–3 spaces of indent). A reference-link *use* is any of:
///
/// * `[text][label]` — full reference
/// * `[label][]` — collapsed reference
/// * `[label]` — shortcut reference (only when `label` resolves against a known definition)
///
/// and the corresponding image shapes (`![alt][label]`, `![label][]`, `![label]`).
///
/// Block-level context: definitions inside fenced code, indented code, and frontmatter are
/// ignored; so are uses on those lines.
public enum ReferenceCollector {

    /// A collected reference-link definition.
    public struct Definition: Equatable, Sendable {
        /// The raw label text between the brackets, before normalization.
        public let rawLabel: String
        /// The normalized label (lowercased, whitespace collapsed).
        public let label: String
        /// 1-indexed source line of the definition.
        public let line: Int
        /// Destination (URL) portion, trimmed.
        public let destination: String
        /// Optional title portion, trimmed.
        public let title: String?

        public init(
            rawLabel: String,
            label: String,
            line: Int,
            destination: String,
            title: String?
        ) {
            self.rawLabel = rawLabel
            self.label = label
            self.line = line
            self.destination = destination
            self.title = title
        }
    }

    /// A reference-link use — i.e. one of the reference/collapsed/shortcut forms.
    public struct Use: Equatable, Sendable {
        /// Normalized label as resolved against the definition table.
        public let label: String
        /// The raw label text between brackets (text portion for shortcut/collapsed, otherwise
        /// the explicit label portion).
        public let rawLabel: String
        /// 1-indexed source line where the use appears.
        public let line: Int
        /// True for image uses, false for link uses.
        public let isImage: Bool
        /// Shape of the reference.
        public let kind: InlineTokenizer.LinkKind

        public init(
            label: String,
            rawLabel: String,
            line: Int,
            isImage: Bool,
            kind: InlineTokenizer.LinkKind
        ) {
            self.label = label
            self.rawLabel = rawLabel
            self.line = line
            self.isImage = isImage
            self.kind = kind
        }
    }

    /// Aggregated result of scanning a document.
    public struct CollectedReferences: Equatable, Sendable {
        public let definitions: [Definition]
        public let uses: [Use]
        /// Set of normalized labels that have at least one definition.
        public let knownLabels: Set<String>

        public init(definitions: [Definition], uses: [Use], knownLabels: Set<String>) {
            self.definitions = definitions
            self.uses = uses
            self.knownLabels = knownLabels
        }
    }

    /// Collect just the normalized labels that have at least one reference definition.
    ///
    /// Rules that only need to resolve shortcut references (e.g. for `InlineTokenizer.inlineLinks`)
    /// should use this — it skips the per-line inline-link re-scan that `collect(from:)` runs
    /// for the `uses` list.
    public static func knownLabels(from content: String) -> Set<String> {
        let lines = splitLines(content)
        let skipLines = linesToSkip(content: content)
        return Set(collectDefinitions(lines: lines, skipLines: skipLines).map(\.label))
    }

    /// Collect reference definitions and uses from `content`.
    public static func collect(from content: String) -> CollectedReferences {
        let lines = splitLines(content)
        let skipLines = linesToSkip(content: content)

        let definitions = collectDefinitions(lines: lines, skipLines: skipLines)
        let knownLabels = Set(definitions.map(\.label))

        var uses: [Use] = []
        for (idx, line) in lines.enumerated() {
            let number = idx + 1
            if skipLines.contains(number) { continue }
            // Reference-definition lines also contain a `[label]:` shape — don't double count
            // the definition as a use.
            if isReferenceDefinitionLine(line) { continue }

            for link in InlineTokenizer.inlineLinks(in: line, knownLabels: knownLabels) {
                switch link.kind {
                case .inline:
                    continue
                case .reference:
                    let rawLabel =
                        link.labelRange.map { String(line[$0]) } ?? String(line[link.textRange])
                    uses.append(
                        Use(
                            label: InlineTokenizer.normalizeLabel(rawLabel),
                            rawLabel: rawLabel,
                            line: number,
                            isImage: link.isImage,
                            kind: link.kind
                        )
                    )
                case .collapsed, .shortcut:
                    let rawLabel = String(line[link.textRange])
                    uses.append(
                        Use(
                            label: InlineTokenizer.normalizeLabel(rawLabel),
                            rawLabel: rawLabel,
                            line: number,
                            isImage: link.isImage,
                            kind: link.kind
                        )
                    )
                }
            }
        }
        return CollectedReferences(
            definitions: definitions,
            uses: uses,
            knownLabels: knownLabels
        )
    }

    /// Set of 1-indexed lines that should be treated as opaque (fenced/indented code + frontmatter).
    public static func linesToSkip(content: String) -> Set<Int> {
        var set: Set<Int> = []
        for block in BlockTokenizer.tokenize(content) {
            switch block.kind {
            case .fencedCode, .indentedCode, .frontmatter:
                for line in block.startLine...block.endLine {
                    set.insert(line)
                }
            default:
                continue
            }
        }
        return set
    }

    /// True when the line has the shape `[label]: …` with optional 0–3 leading spaces.
    public static func isReferenceDefinitionLine(_ line: String) -> Bool {
        parseDefinition(line: line) != nil
    }

    // MARK: - Definition parsing

    private static func collectDefinitions(
        lines: [String],
        skipLines: Set<Int>
    ) -> [Definition] {
        var definitions: [Definition] = []
        for (idx, line) in lines.enumerated() {
            let number = idx + 1
            if skipLines.contains(number) { continue }
            guard let parsed = parseDefinition(line: line) else { continue }
            definitions.append(
                Definition(
                    rawLabel: parsed.rawLabel,
                    label: InlineTokenizer.normalizeLabel(parsed.rawLabel),
                    line: number,
                    destination: parsed.destination,
                    title: parsed.title
                )
            )
        }
        return definitions
    }

    private struct ParsedDefinition {
        let rawLabel: String
        let destination: String
        let title: String?
    }

    private static func parseDefinition(line: String) -> ParsedDefinition? {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex, line[cursor] == "[" else { return nil }
        let labelOpen = cursor
        cursor = line.index(after: cursor)
        while cursor < line.endIndex, line[cursor] != "]" {
            if line[cursor] == "\\", line.index(after: cursor) < line.endIndex {
                cursor = line.index(after: cursor)
            }
            cursor = line.index(after: cursor)
        }
        guard cursor < line.endIndex, line[cursor] == "]" else { return nil }
        let labelClose = cursor
        cursor = line.index(after: cursor)
        guard cursor < line.endIndex, line[cursor] == ":" else { return nil }
        cursor = line.index(after: cursor)
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        let destinationStart = cursor
        while cursor < line.endIndex,
            line[cursor] != " ", line[cursor] != "\t"
        {
            cursor = line.index(after: cursor)
        }
        let destination = String(line[destinationStart..<cursor]).trimmingCharacters(
            in: .whitespaces
        )
        guard !destination.isEmpty else { return nil }
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        var title: String?
        if cursor < line.endIndex {
            let ch = line[cursor]
            if ch == "\"" || ch == "'" {
                let quote = ch
                let titleOpen = line.index(after: cursor)
                var titleEnd = titleOpen
                while titleEnd < line.endIndex, line[titleEnd] != quote {
                    if line[titleEnd] == "\\",
                        line.index(after: titleEnd) < line.endIndex
                    {
                        titleEnd = line.index(after: titleEnd)
                    }
                    titleEnd = line.index(after: titleEnd)
                }
                if titleEnd < line.endIndex {
                    title = String(line[titleOpen..<titleEnd])
                }
            }
        }
        let rawLabel = String(line[line.index(after: labelOpen)..<labelClose])
        return ParsedDefinition(rawLabel: rawLabel, destination: destination, title: title)
    }

    private static func splitLines(_ content: String) -> [String] {
        var lines = content.components(separatedBy: .newlines)
        if content.hasSuffix("\n"), lines.last == "" {
            lines.removeLast()
        }
        return lines
    }
}

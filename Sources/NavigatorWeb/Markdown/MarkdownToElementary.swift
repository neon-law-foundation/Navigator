import Elementary
import Markdown

/// A type-erased HTML node carrying pre-rendered HTML text.
///
/// Elementary's typed element builders (`h1 { … }`, `p { … }`, etc.) produce
/// elements whose static types differ by content, so we cannot return them
/// directly from the heterogeneous `visit…` methods required by
/// `MarkupVisitor`. We bottom-up render each visited node to a string and
/// wrap it here; the outer document concatenates those strings unchanged.
public struct AnyHTML: HTML, Sendable {
    /// The already-rendered HTML string.
    public var rendered: String

    public init(_ rendered: String) {
        self.rendered = rendered
    }

    public init(_ html: some HTML) {
        self.rendered = html.render()
    }

    public var body: some HTML {
        HTMLRaw(rendered)
    }
}

/// Converts a parsed swift-markdown `Document` into an Elementary `HTML` tree.
///
/// Covers every CommonMark block and inline node in `swift-markdown`'s public
/// API plus the GFM extensions (tables, strikethrough, task-list checkboxes).
/// Footnotes are intentionally out of scope until they ship in a tagged
/// `swift-markdown` release.
///
/// - Important: Raw HTML — both ``Markdown/HTMLBlock`` and
///   ``Markdown/InlineHTML`` — is treated as plain text and HTML-escaped on
///   output. The CommonMark spec permits raw passthrough, but doing so would
///   let untrusted markdown inject `<script>` (or any other) tags into rendered
///   pages. We deliberately give up that fidelity in exchange for a renderer
///   that is safe to point at user-authored content. A future opt-in could
///   expose raw passthrough for trusted callers.
public struct MarkdownToElementary: MarkupVisitor {
    public typealias Result = AnyHTML

    /// Per-column alignments for the table currently being rendered, if any.
    /// Set on entry to `visitTable` and cleared on exit so nested tables work.
    private var currentColumnAlignments: [Table.ColumnAlignment?] = []

    /// `true` while we are walking the cells of a `Table.Head`, so that
    /// `visitTableCell` can emit `<th>` instead of `<td>`.
    private var inTableHead: Bool = false

    public init() {}

    // MARK: - Default fallback

    public mutating func defaultVisit(_ markup: any Markup) -> AnyHTML {
        AnyHTML(renderChildren(of: markup))
    }

    // MARK: - Document

    public mutating func visitDocument(_ document: Document) -> AnyHTML {
        AnyHTML(renderChildren(of: document))
    }

    // MARK: - Block nodes

    public mutating func visitHeading(_ heading: Heading) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: heading))
        switch heading.level {
        case 1: return AnyHTML(h1 { inner })
        case 2: return AnyHTML(h2 { inner })
        case 3: return AnyHTML(h3 { inner })
        case 4: return AnyHTML(h4 { inner })
        case 5: return AnyHTML(h5 { inner })
        default: return AnyHTML(h6 { inner })
        }
    }

    public mutating func visitParagraph(_ paragraph: Paragraph) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: paragraph))
        return AnyHTML(p { inner })
    }

    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: blockQuote))
        return AnyHTML(blockquote { inner })
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> AnyHTML {
        // GFM and most CommonMark renderers preserve the trailing newline that
        // closes the fenced block. swift-markdown's `code` already includes it.
        let escapedBody = HTMLRaw(codeBlock.code.htmlEscaped)
        if let language = codeBlock.language, !language.isEmpty {
            return AnyHTML(
                pre {
                    code(.class("language-\(language)")) { escapedBody }
                }
            )
        }
        return AnyHTML(pre { code { escapedBody } })
    }

    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> AnyHTML {
        AnyHTML(hr())
    }

    public mutating func visitHTMLBlock(_ html: HTMLBlock) -> AnyHTML {
        // Escape-by-default — see the type-level doc comment for rationale.
        AnyHTML(html.rawHTML.htmlEscaped)
    }

    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: unorderedList))
        return AnyHTML(ul { inner })
    }

    public mutating func visitOrderedList(_ orderedList: OrderedList) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: orderedList))
        if orderedList.startIndex != 1 {
            return AnyHTML(
                ol(.init(name: "start", value: String(orderedList.startIndex))) { inner }
            )
        }
        return AnyHTML(ol { inner })
    }

    public mutating func visitListItem(_ listItem: ListItem) -> AnyHTML {
        let body = renderChildren(of: listItem)
        if let checkbox = listItem.checkbox {
            let checkedAttr = checkbox == .checked ? " checked" : ""
            // Emit the GFM task-list checkbox as a disabled <input>; matches
            // cmark-gfm's HTML output and what GitHub renders.
            let inputHTML = "<input type=\"checkbox\" disabled\(checkedAttr)> "
            return AnyHTML("<li>\(inputHTML)\(body)</li>")
        }
        return AnyHTML(li { HTMLRaw(body) })
    }

    // MARK: - Tables

    public mutating func visitTable(_ table: Table) -> AnyHTML {
        let previousAlignments = currentColumnAlignments
        currentColumnAlignments = table.columnAlignments
        defer { currentColumnAlignments = previousAlignments }

        var buffer = ""
        for child in table.children {
            buffer += child.accept(&self).rendered
        }
        return AnyHTML(Elementary.table { HTMLRaw(buffer) })
    }

    public mutating func visitTableHead(_ tableHead: Table.Head) -> AnyHTML {
        let previousInHead = inTableHead
        inTableHead = true
        defer { inTableHead = previousInHead }

        // Wrap head cells in a single <tr> the way cmark-gfm does.
        var buffer = ""
        for child in tableHead.children {
            buffer += child.accept(&self).rendered
        }
        return AnyHTML(thead { tr { HTMLRaw(buffer) } })
    }

    public mutating func visitTableBody(_ tableBody: Table.Body) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: tableBody))
        return AnyHTML(tbody { inner })
    }

    public mutating func visitTableRow(_ tableRow: Table.Row) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: tableRow))
        return AnyHTML(tr { inner })
    }

    public mutating func visitTableCell(_ tableCell: Table.Cell) -> AnyHTML {
        // colspan == 0 means this cell is covered by a previous cell — emit
        // nothing so the row's column count stays correct.
        guard tableCell.colspan != 0 else { return AnyHTML("") }

        let inner = renderChildren(of: tableCell)
        let columnIndex = tableCell.indexInParent
        let alignment =
            currentColumnAlignments.indices.contains(columnIndex)
            ? currentColumnAlignments[columnIndex] : nil
        let styleAttr = alignment.map { " style=\"text-align: \($0.cssValue);\"" } ?? ""
        let colspanAttr = tableCell.colspan > 1 ? " colspan=\"\(tableCell.colspan)\"" : ""
        let rowspanAttr = tableCell.rowspan > 1 ? " rowspan=\"\(tableCell.rowspan)\"" : ""
        let tag = inTableHead ? "th" : "td"
        return AnyHTML("<\(tag)\(styleAttr)\(colspanAttr)\(rowspanAttr)>\(inner)</\(tag)>")
    }

    // MARK: - Inline nodes

    public mutating func visitText(_ text: Text) -> AnyHTML {
        AnyHTML(text.string.htmlEscaped)
    }

    public mutating func visitEmphasis(_ emphasis: Emphasis) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: emphasis))
        return AnyHTML(em { inner })
    }

    public mutating func visitStrong(_ strongNode: Strong) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: strongNode))
        return AnyHTML(strong { inner })
    }

    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: strikethrough))
        return AnyHTML(del { inner })
    }

    public mutating func visitLink(_ link: Link) -> AnyHTML {
        let inner = HTMLRaw(renderChildren(of: link))
        let destination = link.destination ?? ""
        if let title = link.title, !title.isEmpty {
            return AnyHTML(a(.href(destination), .title(title)) { inner })
        }
        return AnyHTML(a(.href(destination)) { inner })
    }

    public mutating func visitImage(_ image: Image) -> AnyHTML {
        // The image's inline children describe the alt text. Concatenate their
        // plainText so emphasis or links inside alt text flatten to a string —
        // alt is an attribute, so it cannot contain markup.
        let altText = image.children.compactMap { $0 as? PlainTextConvertibleMarkup }
            .map { $0.plainText }
            .joined()
        let source = image.source ?? ""
        if let title = image.title, !title.isEmpty {
            return AnyHTML(img(.src(source), .alt(altText), .title(title)))
        }
        return AnyHTML(img(.src(source), .alt(altText)))
    }

    public mutating func visitInlineCode(_ inlineCode: InlineCode) -> AnyHTML {
        AnyHTML(code { HTMLRaw(inlineCode.code.htmlEscaped) })
    }

    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> AnyHTML {
        // Escape-by-default — see the type-level doc comment for rationale.
        AnyHTML(inlineHTML.rawHTML.htmlEscaped)
    }

    public mutating func visitLineBreak(_ lineBreak: LineBreak) -> AnyHTML {
        AnyHTML(br())
    }

    public mutating func visitSoftBreak(_ softBreak: SoftBreak) -> AnyHTML {
        // CommonMark renderers typically emit soft breaks as a single newline.
        AnyHTML("\n")
    }

    // MARK: - Helpers

    private mutating func renderChildren(of markup: any Markup) -> String {
        var buffer = ""
        for child in markup.children {
            buffer += child.accept(&self).rendered
        }
        return buffer
    }
}

/// Parses CommonMark/GFM `source` and returns the rendered HTML body.
///
/// The result is a concatenation of rendered block elements with no outer
/// wrapping — callers embed it inside their own `<html>`/`<body>` layout.
public func renderMarkdown(_ source: String) -> String {
    let document = Document(parsing: source)
    var visitor = MarkdownToElementary()
    return visitor.visit(document).rendered
}

// MARK: - Column alignment helper

extension Table.ColumnAlignment {
    fileprivate var cssValue: String {
        switch self {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        }
    }
}

// MARK: - String escape helper

extension String {
    /// Minimal HTML text escaping for the five named entities that matter when
    /// inserting arbitrary text between tags or inside an attribute value.
    fileprivate var htmlEscaped: String {
        var out = ""
        out.reserveCapacity(count)
        for scalar in unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}

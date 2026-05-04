import Elementary

/// Renders a workshop file — text, markdown, or PDF — with an optional
/// "Highlighted Passages" sidebar.
///
/// When `file` is `nil` the component renders a neutral empty-state
/// prompt. Otherwise it detects the file's render kind (via
/// `file.contentType` with a `.pdf` / `.md` / `.markdown` suffix
/// fallback), then renders the body accordingly:
///
///   * `pdf` — an `<iframe>` pointing at `file.url`. Falls back to a
///     neutral message when no URL is provided.
///   * `markdown` — `file.content` rendered through the M3
///     `renderMarkdown(_:)` pipeline inside a `prose` container.
///   * `text` — `file.content` inside a `<pre>` with `whitespace-pre-wrap`.
///
/// `highlights` are ignored for PDFs (iframe content is not addressable
/// by character offset) and when empty. Otherwise each highlight is
/// server-side sliced out of `file.content` using the half-open
/// `[start, end)` interval (offsets are clamped to valid range) and
/// rendered as a bordered snippet in an `<aside>` next to the body.
///
/// The component carries zero client-side state: highlight slicing,
/// kind detection, and layout switching happen at render time.
public struct DocumentViewer: HTML {
    public let brandColor: String
    public let file: WorkshopFile?
    public let highlights: [DocumentHighlight]

    public init(
        brandColor: String,
        file: WorkshopFile?,
        highlights: [DocumentHighlight] = []
    ) {
        self.brandColor = brandColor
        self.file = file
        self.highlights = highlights
    }

    /// Detection fallback used when `contentType` is not explicitly set.
    /// Keeps name/url suffix detection identical to the archived React
    /// version so migrated callers get the same behaviour.
    private enum Kind {
        case text
        case markdown
        case pdf
    }

    private func detectKind(for file: WorkshopFile) -> Kind {
        if let explicit = file.contentType {
            switch explicit {
            case .text: return .text
            case .markdown: return .markdown
            case .pdf: return .pdf
            }
        }
        let name = file.name.lowercased()
        let url = file.url?.lowercased() ?? ""
        if name.hasSuffix(".pdf") || url.hasSuffix(".pdf") { return .pdf }
        if name.hasSuffix(".md") || name.hasSuffix(".markdown") { return .markdown }
        return .text
    }

    /// Returns the snippet at `highlight`'s offsets, clamped to the valid
    /// range of `content`. Returns `""` when content is absent.
    private func slice(_ content: String?, at highlight: DocumentHighlight) -> String {
        guard let content else { return "" }
        let length = content.count
        let start = max(0, min(highlight.start, length))
        let end = max(start, min(highlight.end, length))
        let startIndex = content.index(content.startIndex, offsetBy: start)
        let endIndex = content.index(content.startIndex, offsetBy: end)
        return String(content[startIndex..<endIndex])
    }

    public var body: some HTML {
        if let file {
            let kind = detectKind(for: file)
            let showHighlights = kind != .pdf && !highlights.isEmpty
            div(.class("flex-1 flex overflow-hidden")) {
                div(
                    .class(
                        "flex flex-col overflow-hidden \(showHighlights ? "flex-1" : "w-full")"
                    )
                ) {
                    div(.class("px-6 py-4 border-b border-gray-200 bg-white flex-shrink-0")) {
                        p(
                            .class("text-xs font-semibold uppercase tracking-wider mb-1"),
                            .style("color:\(brandColor)")
                        ) { file.category }
                        h2(.class("text-lg font-semibold text-gray-800")) { file.name }
                    }
                    div(.class("flex-1 overflow-y-auto bg-gray-50")) {
                        renderBody(file: file, kind: kind)
                    }
                }
                if showHighlights {
                    aside(
                        .class(
                            "w-64 border-l border-gray-200 bg-white overflow-y-auto flex-shrink-0"
                        )
                    ) {
                        h3(
                            .class(
                                "px-4 py-3 border-b border-gray-200 text-xs font-semibold uppercase tracking-wider m-0"
                            ),
                            .style("color:\(brandColor)")
                        ) { "Highlighted Passages" }
                        ul(.class("divide-y divide-gray-100")) {
                            for highlight in highlights {
                                li(.class("px-4 py-3")) {
                                    p(
                                        .class(
                                            "text-xs text-gray-600 leading-relaxed border-l-2 pl-3"
                                        ),
                                        .style("border-color:\(brandColor)")
                                    ) { slice(file.content, at: highlight) }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            div(.class("flex-1 flex items-center justify-center text-gray-400 text-sm")) {
                "Select a document to view its contents."
            }
        }
    }

    @HTMLBuilder
    private func renderBody(file: WorkshopFile, kind: Kind) -> some HTML {
        switch kind {
        case .pdf:
            if let url = file.url {
                iframe(
                    .src(url),
                    .class("w-full h-full border-0"),
                    .custom(name: "title", value: file.name)
                ) {}
            } else {
                p(.class("p-6 text-gray-400 text-sm italic")) {
                    "PDF has no URL to render."
                }
            }
        case .markdown:
            if let content = file.content {
                div(.class("p-6 prose prose-sm max-w-none text-gray-700")) {
                    AnyHTML(renderMarkdown(content))
                }
            } else {
                p(.class("p-6 text-gray-400 text-sm italic")) { "No content available." }
            }
        case .text:
            if let content = file.content {
                pre(
                    .class(
                        "p-6 whitespace-pre-wrap font-mono text-sm text-gray-700 leading-relaxed"
                    )
                ) { content }
            } else {
                p(.class("p-6 text-gray-400 text-sm italic")) { "No content available." }
            }
        }
    }
}

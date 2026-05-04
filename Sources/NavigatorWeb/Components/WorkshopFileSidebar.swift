import Elementary

/// Renders a vertical sidebar of workshop files grouped by category.
///
/// File selection is a plain anchor navigation: each file link points at
/// `\(basePath)?file=\(id)`, leaving the full-page swap to the browser (or
/// to an HTMX swap wired by the caller at a higher level). Selected state
/// is determined server-side by comparing `file.id` against `activeFileId`;
/// the matching entry gets a distinct Tailwind class string plus
/// `aria-current="page"`. Passing `activeFileId: nil` — or an id that does
/// not match any file — emits no active state.
///
/// Separate from `ProjectSidebar` by design: that component lists projects
/// (`WebProject`); this one lists files (`WorkshopFile`) grouped by
/// `category` for use inside a project. Composed by `WorkshopWorkspace`.
public struct WorkshopFileSidebar: HTML {
    public let files: [WorkshopFile]
    public let activeFileId: String?
    public let basePath: String
    public let brandColor: String

    public init(
        files: [WorkshopFile],
        activeFileId: String?,
        basePath: String,
        brandColor: String
    ) {
        self.files = files
        self.activeFileId = activeFileId
        self.basePath = basePath
        self.brandColor = brandColor
    }

    /// Stable category ordering: categories appear in the order their first
    /// file appears in `files`. Files keep their relative order within a
    /// category. This matches the TSX original's behaviour — no implicit
    /// alphabetisation.
    private var grouped: [(category: String, files: [WorkshopFile])] {
        var order: [String] = []
        var buckets: [String: [WorkshopFile]] = [:]
        for file in files {
            if buckets[file.category] == nil {
                order.append(file.category)
                buckets[file.category] = []
            }
            buckets[file.category]?.append(file)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    public var body: some HTML {
        nav(
            .class("workshop-file-sidebar w-64 border-r border-gray-200 bg-white overflow-y-auto"),
            .custom(name: "aria-label", value: "Workshop files")
        ) {
            for group in grouped {
                div(.class("py-2")) {
                    h3(
                        .class(
                            "px-4 py-2 text-xs font-semibold uppercase tracking-wider text-gray-500"
                        )
                    ) { group.category }
                    ul(.class("flex flex-col")) {
                        for file in group.files {
                            li {
                                if file.id == activeFileId {
                                    a(
                                        .href("\(basePath)?file=\(file.id)"),
                                        .class(
                                            "block px-4 py-2 text-sm text-white font-medium"
                                        ),
                                        .style("background-color:\(brandColor)"),
                                        .custom(name: "aria-current", value: "page")
                                    ) { file.name }
                                } else {
                                    a(
                                        .href("\(basePath)?file=\(file.id)"),
                                        .class(
                                            "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
                                        )
                                    ) { file.name }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

import Elementary

/// Renders prev/next pagination controls for paged blog index views.
///
/// `current` is 1-indexed; `total` is the total number of pages. When
/// `current == 1` the previous control is rendered as a non-link
/// `aria-disabled` span; symmetrically for `current == total` on the
/// next control. Generated links carry `?page=<n>` against the
/// supplied `basePath`.
public struct BlogPagination: HTML {
    public let current: Int
    public let total: Int
    public let basePath: String

    public init(current: Int, total: Int, basePath: String) {
        self.current = current
        self.total = total
        self.basePath = basePath
    }

    public var body: some HTML {
        nav(
            .class("flex items-center justify-between py-6"),
            .custom(name: "aria-label", value: "Pagination")
        ) {
            if current > 1 {
                a(
                    .href("\(basePath)?page=\(current - 1)"),
                    .class(
                        "text-sm text-gray-700 hover:text-gray-900 transition-colors"
                    )
                ) { "Previous" }
            } else {
                span(
                    .class("text-sm text-gray-400 cursor-not-allowed"),
                    .custom(name: "aria-disabled", value: "true")
                ) { "Previous" }
            }
            span(.class("text-sm text-gray-500")) {
                "Page \(current) of \(total)"
            }
            if current < total {
                a(
                    .href("\(basePath)?page=\(current + 1)"),
                    .class(
                        "text-sm text-gray-700 hover:text-gray-900 transition-colors"
                    )
                ) { "Next" }
            } else {
                span(
                    .class("text-sm text-gray-400 cursor-not-allowed"),
                    .custom(name: "aria-disabled", value: "true")
                ) { "Next" }
            }
        }
    }
}

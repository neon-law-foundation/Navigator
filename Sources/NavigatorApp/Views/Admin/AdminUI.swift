import Elementary

/// Standard `<th>` for admin tables. Keeps the consistent spacing and
/// typography in one place so every resource list reads the same way.
struct AdminTableHeader: HTML {
    let label: String
    let alignment: Alignment

    enum Alignment: Sendable {
        case left
        case right
    }

    init(_ label: String, alignment: Alignment = .left) {
        self.label = label
        self.alignment = alignment
    }

    var body: some HTML {
        th(
            .class(
                "px-4 py-3 text-\(alignment == .right ? "right" : "left") text-xs font-semibold uppercase tracking-wide text-gray-600"
            )
        ) { label }
    }
}

/// Green banner rendered above an index page when a flash message has
/// round-tripped through the query string.
struct AdminFlashBanner: HTML {
    let message: String?

    var body: some HTML {
        if let message {
            div(
                .class(
                    "mb-4 rounded-md border border-green-300 bg-green-50 p-3 text-sm text-green-800"
                ),
                .custom(name: "role", value: "status")
            ) { message }
        }
    }
}

/// Empty-state card rendered when an admin index has no rows.
struct AdminEmptyState: HTML {
    let message: String
    let ctaHref: String
    let ctaLabel: String

    var body: some HTML {
        div(
            .class("rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white")
        ) {
            p(.class("text-gray-600")) { message }
            a(.href(ctaHref), .class("text-indigo-600 hover:underline")) { ctaLabel }
        }
    }
}

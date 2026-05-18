import Elementary

/// Search bar for admin index pages.
///
/// Renders a `GET` form whose `q` input survives across reloads — the
/// caller passes the active filter back in via `value:` so the rendered
/// `<input>` reflects the operator's last query. Pair with
/// ``NavigatorWeb/DataTable``'s `queryItems:` so sort clicks preserve
/// the filter.
///
/// The form's submit method is `GET` so the URL alone captures the
/// filtered view — operators can bookmark or share the link.
struct AdminFilterBar: HTML {
    let action: String
    let value: String
    let placeholder: String

    init(action: String, value: String, placeholder: String = "Search\u{2026}") {
        self.action = action
        self.value = value
        self.placeholder = placeholder
    }

    var body: some HTML {
        form(
            .action(action),
            .method(.get),
            .class("mb-4 flex items-center gap-2")
        ) {
            input(
                .type(.search),
                .name("q"),
                .value(value),
                .custom(name: "placeholder", value: placeholder),
                .class(
                    "block w-64 rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-300"
                )
            )
            button(
                .type(.submit),
                .class(
                    "inline-flex items-center px-3 py-1.5 rounded-md text-sm font-medium bg-gray-200 text-gray-800 hover:bg-gray-300"
                )
            ) { "Search" }
            if !value.isEmpty {
                a(.href(action), .class("text-xs text-gray-500 hover:underline")) {
                    "Clear"
                }
            }
        }
    }
}

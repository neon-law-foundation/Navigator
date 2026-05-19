import Elementary
import NavigatorWeb

/// Admin-chromed error page rendered by ``AdminErrorMiddleware``.
///
/// The default Vapor renderer emits plain text for `404` and `503`,
/// which jolts an operator out of the admin chrome. This page wraps
/// the error in the same ``AdminPageLayout`` so the sidebar stays
/// visible and the operator has a clear path back to a known section.
struct AdminErrorPage: HTML {
    let brand: any Brand
    let status: Int
    let title: String
    let message: String

    var body: some HTML {
        AdminPageLayout(
            pageTitle: title,
            activeSection: .dashboard,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white rounded-lg border border-gray-200 p-8")) {
                p(.class("text-xs font-mono uppercase tracking-wide text-gray-500 mb-2")) {
                    "Status \(status)"
                }
                h2(.class("text-2xl font-bold text-gray-900 mb-3")) { title }
                p(.class("text-sm text-gray-700 mb-6")) { message }
                div(.class("flex items-center gap-3")) {
                    LinkButton("Back to dashboard", href: "/admin", variant: .primary)
                    LinkButton("Health probe", href: "/health")
                }
            }
        }
    }
}

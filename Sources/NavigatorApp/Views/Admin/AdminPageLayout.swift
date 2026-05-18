import Elementary
import NavigatorWeb

/// HTML document layout shared by every admin page.
///
/// Distinct from ``PageLayout`` (the public-site document) because admin
/// pages render a fixed sidebar instead of the public site navigation and
/// footer. The `<head>` reuses the same Tailwind CDN reference so the
/// styles stay consistent.
struct AdminPageLayout<Content: HTML>: HTMLDocument {
    let pageTitle: String
    let activeSection: AdminSection
    let brand: any Brand
    @HTMLBuilder var content: () -> Content

    var title: String { "\(pageTitle) - \(brand.name) Admin" }
    var lang: String { "en" }

    var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        // Admin pages must not surface in search; the rest of the site
        // controls indexability per-page so any robots header inherits.
        meta(.name("robots"), .content("noindex, nofollow"))
        link(.rel(.icon), .href("/favicon.svg"))
        script(.src("https://cdn.tailwindcss.com")) {}
    }

    var body: some HTML {
        div(.class("min-h-screen bg-gray-100 flex")) {
            AdminSidebar(active: activeSection)
            div(.class("flex-1 flex flex-col")) {
                AdminPageHeader(pageTitle: pageTitle, activeSection: activeSection)
                main(.class("flex-1 px-8 py-6")) {
                    content()
                }
            }
        }
    }
}

/// Sticky-feeling header that prints the current section and page title.
/// Pages use the same chrome regardless of resource so the layout cost
/// stays paid once.
struct AdminPageHeader: HTML {
    let pageTitle: String
    let activeSection: AdminSection

    var body: some HTML {
        header(.class("bg-white border-b border-gray-200 px-8 py-4")) {
            p(.class("text-xs uppercase tracking-wide text-gray-500")) {
                activeSection.label
            }
            h1(.class("text-2xl font-bold text-gray-900")) { pageTitle }
        }
    }
}

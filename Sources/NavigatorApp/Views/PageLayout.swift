import Elementary
import NavigatorWeb

/// Shared outer HTML document used by every server-rendered page.
struct PageLayout<Content: HTML>: HTMLDocument {
    /// Canonical absolute base URL used when building Open Graph `og:url`
    /// and image URLs. Hard-coded to the production site so shared links
    /// from staging still resolve to the canonical destination.
    static var siteBaseURL: String { "https://www.neonlaw.com" }

    let pageTitle: String
    let pageDescription: String
    let brand: any Brand
    var ogType: String = "website"
    var canonicalPath: String? = nil
    @HTMLBuilder var content: () -> Content

    var title: String { "\(pageTitle) - \(brand.name)" }
    var lang: String { "en" }

    private var canonicalURL: String? {
        canonicalPath.map { "\(Self.siteBaseURL)\($0)" }
    }

    private var svgImageURL: String { "\(Self.siteBaseURL)/logo.svg" }
    private var pngImageURL: String { "\(Self.siteBaseURL)/logo.png" }

    var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        meta(.name(.description), .content(pageDescription))
        link(.rel(.icon), .href("/favicon.svg"))

        // Open Graph. SVG is listed first because the user-facing intent is
        // to share the logo SVG; PNG follows as a fallback for crawlers
        // that reject vector images (Facebook, X, LinkedIn at the time of
        // writing).
        meta(.property("og:title"), .content(pageTitle))
        meta(.property("og:description"), .content(pageDescription))
        meta(.property("og:type"), .content(ogType))
        meta(.property("og:site_name"), .content(brand.name))
        if let canonicalURL {
            meta(.property("og:url"), .content(canonicalURL))
        }
        meta(.property("og:image"), .content(svgImageURL))
        meta(.property("og:image:type"), .content("image/svg+xml"))
        meta(.property("og:image:alt"), .content(brand.name))
        meta(.property("og:image"), .content(pngImageURL))
        meta(.property("og:image:type"), .content("image/png"))

        // Twitter card. X does not render SVG previews, so the Twitter
        // image is always the PNG.
        meta(.name("twitter:card"), .content("summary"))
        meta(.name("twitter:title"), .content(pageTitle))
        meta(.name("twitter:description"), .content(pageDescription))
        meta(.name("twitter:image"), .content(pngImageURL))

        script(.src("https://cdn.tailwindcss.com")) {}
    }

    var body: some HTML {
        div(.class("min-h-screen bg-white flex flex-col")) {
            SiteNav(brand: brand)
            div(.class("flex-1")) {
                content()
            }
            SiteFooter(brand: brand, year: 2026)
        }
    }
}

/// Brand-aware top navigation bar with a "Support Us" CTA.
///
/// Distinct from `NavigatorWeb.SiteHeader` (which carries an auth-user
/// slot and no donation CTA) because NLF is a non-profit and every page
/// ends in a donation link.
struct SiteNav: HTML {
    let brand: any Brand

    var body: some HTML {
        nav(.class("bg-white border-b border-gray-200"), .custom(name: "data-brand", value: brand.name)) {
            div(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between")) {
                a(.href("/"), .class("flex items-center gap-3")) {
                    img(.src(brand.logoPath), .alt(brand.name), .class("h-10 w-auto"))
                    span(.class("font-semibold text-gray-900")) { brand.name }
                }
                div(.class("flex items-center gap-6")) {
                    for link in brand.navLinks {
                        a(
                            .href(link.href),
                            .class("text-gray-700 hover:text-gray-900 font-medium")
                        ) { link.label }
                    }
                    a(
                        .href("mailto:support@neonlaw.org?subject=Support the Neon Law Foundation"),
                        .class("px-4 py-2 rounded-lg font-semibold text-white"),
                        .style("background-color:\(brand.primaryColor)")
                    ) { "Support Us" }
                }
            }
        }
    }
}

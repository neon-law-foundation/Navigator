import Elementary

/// Renders a brand-aware site header with desktop nav and an HTMX-driven
/// mobile menu toggle.
///
/// Desktop: a horizontal `nav` reading `brand.navLinks` plus a small account
/// area on the right. Mobile: a button that issues `hx-get="/fragments/mobile-nav"`
/// and swaps the response into `#mobile-nav` via `outerHTML`. The fragment
/// route itself is not implemented here — that lives with the Vapor route
/// layer in a later milestone.
///
/// Tailwind utility classes are emitted as-is via `.class(...)` so a single
/// Tailwind build over the Swift sources produces the matching CSS.
public struct SiteHeader: HTML {
    public let brand: any Brand
    public let authUser: WebUser?

    public init(brand: any Brand, authUser: WebUser? = nil) {
        self.brand = brand
        self.authUser = authUser
    }

    public var body: some HTML {
        header(
            .class("bg-white border-b border-gray-200"),
            .custom(name: "data-brand", value: brand.name)
        ) {
            div(.class("max-w-7xl mx-auto px-4 py-4 flex items-center justify-between")) {
                a(
                    .href("/"),
                    .class("flex items-center gap-2 font-semibold"),
                    .style("color:\(brand.primaryColor)")
                ) {
                    img(
                        .src(brand.logoPath),
                        .alt("\(brand.name) logo"),
                        .class("h-8 w-8")
                    )
                    span { brand.name }
                }
                nav(.class("hidden md:flex items-center gap-6")) {
                    for link in brand.navLinks {
                        a(
                            .href(link.href),
                            .class("text-sm text-gray-700 hover:text-gray-900 transition-colors")
                        ) { link.label }
                    }
                }
                div(.class("flex items-center gap-3")) {
                    if let authUser {
                        span(.class("hidden md:inline text-sm text-gray-700")) {
                            authUser.displayName
                        }
                        a(
                            .href("/logout"),
                            .class("text-sm text-gray-700 hover:text-gray-900 transition-colors")
                        ) { "Sign out" }
                    } else {
                        a(
                            .href("/login"),
                            .class("text-sm text-gray-700 hover:text-gray-900 transition-colors")
                        ) { "Sign in" }
                    }
                    button(
                        .type(.button),
                        .class(
                            "md:hidden inline-flex items-center justify-center p-2 rounded text-gray-700 hover:bg-gray-100"
                        ),
                        .custom(name: "aria-label", value: "Open menu"),
                        .custom(name: "hx-get", value: "/fragments/mobile-nav"),
                        .custom(name: "hx-target", value: "#mobile-nav"),
                        .custom(name: "hx-swap", value: "outerHTML")
                    ) { "Menu" }
                }
            }
            div(.id("mobile-nav"), .class("md:hidden")) {}
        }
    }
}

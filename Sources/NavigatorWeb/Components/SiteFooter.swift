import Elementary

/// Renders a brand-aware site footer.
///
/// Emits the same Tailwind utility classes the React/TSX components emit so
/// that a single Tailwind build pass over the Swift sources produces the
/// same CSS. `year` is injected rather than computed so snapshot tests are
/// deterministic.
public struct SiteFooter: HTML {
    public let brand: any Brand
    public let year: Int

    public init(brand: any Brand, year: Int) {
        self.brand = brand
        self.year = year
    }

    public var body: some HTML {
        footer(
            .class("bg-gray-900 text-gray-300 py-8"),
            .custom(name: "data-brand", value: brand.name)
        ) {
            div(.class("max-w-7xl mx-auto px-4")) {
                div(.class("flex flex-col md:flex-row justify-between items-center gap-4")) {
                    p(.class("text-sm")) {
                        "\u{00A9} \(year) \(brand.name). All rights reserved."
                    }
                    nav(.class("flex gap-4")) {
                        for link in brand.footerLinks {
                            a(
                                .href(link.href),
                                .class("text-sm hover:text-white transition-colors")
                            ) { link.label }
                        }
                    }
                }
            }
        }
    }
}

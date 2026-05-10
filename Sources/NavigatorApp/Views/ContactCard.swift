import Elementary
import NavigatorWeb

struct ContactCard: HTML {
    let label: String
    let value: String
    let href: String
    let brand: any Brand

    var body: some HTML {
        div(.class("bg-cyan-50 p-8 rounded-xl border border-cyan-100")) {
            p(.class("font-semibold text-gray-900 mb-2")) { label }
            a(
                .href(href),
                .class("hover:underline"),
                .style("color:\(brand.primaryColor)")
            ) { value }
        }
    }
}

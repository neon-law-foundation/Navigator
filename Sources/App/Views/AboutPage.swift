import Elementary
import NavigatorWeb

/// The `/about` page.
struct AboutPage: HTML {
    let brand: any Brand

    var body: some HTML {
        PageLayout(
            pageTitle: "About",
            pageDescription: "About the Neon Law Foundation.",
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-4xl font-bold text-gray-900 mb-6")) { "About the Foundation" }
                p(.class("text-lg text-gray-700 mb-6 leading-relaxed")) {
                    "The Neon Law Foundation is a 501(c)(3) nonprofit focused on closing the "
                    "justice gap through AI-powered tools, workflow automation, and continuing "
                    "legal education."
                }
                p(.class("text-lg text-gray-700 mb-6 leading-relaxed")) {
                    "We believe that the combination of modern software and well-trained lawyers "
                    "can dramatically expand the number of people who receive competent legal "
                    "help. Our programs target the steps in a legal matter where technology "
                    "produces the most leverage: intake, document assembly, research, and "
                    "review."
                }
                p(.class("text-lg text-gray-700 mb-6 leading-relaxed")) {
                    "Everything we build is open, well-documented, and available to legal aid "
                    "organizations and pro bono attorneys at no cost. We do not sell software."
                }
                p(.class("text-lg text-gray-700 leading-relaxed")) {
                    "Questions? Email "
                    a(
                        .href("mailto:support@neonlaw.org"),
                        .class("hover:underline"),
                        .style("color:\(brand.primaryColor)")
                    ) { "support@neonlaw.org" }
                    "."
                }
            }
        }
    }
}

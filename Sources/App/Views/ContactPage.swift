import Elementary
import NavigatorWeb

/// The `/contact` page.
struct ContactPage: HTML {
    let brand: any Brand

    var body: some HTML {
        PageLayout(
            pageTitle: "Contact",
            pageDescription: "Get in touch with the Neon Law Foundation.",
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-4xl font-bold text-gray-900 mb-6")) { "Contact Us" }
                p(.class("text-lg text-gray-700 mb-10")) {
                    "Reach out with questions, CLE programming requests, or partnership ideas."
                }
                div(.class("grid grid-cols-1 sm:grid-cols-2 gap-6")) {
                    ContactCard(
                        label: "Email",
                        value: "support@neonlaw.org",
                        href: "mailto:support@neonlaw.org",
                        brand: brand
                    )
                    ContactCard(
                        label: "GitHub",
                        value: "neon-law-foundation",
                        href: "https://github.com/neon-law-foundation",
                        brand: brand
                    )
                }
            }
        }
    }
}

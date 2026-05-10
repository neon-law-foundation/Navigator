import Elementary
import NavigatorWeb

/// The `/terms` page. Same content shape as `PrivacyPage`.
struct TermsPage: HTML {
    let brand: any Brand

    private let sections: [(heading: String, body: String)] = [
        (
            "Acceptance of Terms",
            "By accessing or using the Neon Law Foundation website and services, you agree to "
                + "be bound by these Terms of Service. If you do not agree, please do not use "
                + "our services."
        ),
        (
            "Non-Profit Mission",
            "The Neon Law Foundation is a 501(c)(3) non-profit organization. Our services are "
                + "provided to advance our charitable mission of expanding access to justice. "
                + "Donations made to the Foundation may be tax-deductible to the extent "
                + "permitted by law."
        ),
        (
            "No Legal Advice Without Engagement",
            "Information on this website is for general informational and educational purposes "
                + "only and does not constitute legal advice. An attorney-client relationship is "
                + "formed only upon execution of a written engagement agreement through our "
                + "Legal Aid program."
        ),
        (
            "Use of Services",
            "Our programs and resources are intended for lawful purposes consistent with the "
                + "Foundation's mission. You agree not to misuse any information or services "
                + "provided, and to provide accurate information when requesting legal "
                + "assistance."
        ),
        (
            "Contact Us",
            "If you have questions about these Terms, please contact us at support@neonlaw.org."
        ),
    ]

    var body: some HTML {
        PageLayout(
            pageTitle: "Terms of Service",
            pageDescription: "Terms of Service for the Neon Law Foundation.",
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-3xl font-bold text-gray-900 mb-8")) { "Terms of Service" }
                div(.class("space-y-8")) {
                    for entry in sections {
                        div {
                            h2(.class("text-xl font-semibold text-gray-900 mb-4")) {
                                entry.heading
                            }
                            p(.class("text-gray-700")) { entry.body }
                        }
                    }
                }
            }
        }
    }
}

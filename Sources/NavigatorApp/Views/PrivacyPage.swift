import Elementary
import NavigatorWeb

/// The `/privacy` page.
struct PrivacyPage: HTML {
    let brand: any Brand

    private let sections: [(heading: String, body: String)] = [
        (
            "Information We Collect",
            "We collect information you provide directly to us, such as when you contact us, "
                + "make a donation, request legal assistance, or sign up for our programs. This "
                + "may include your name, email address, phone number, and other relevant "
                + "information."
        ),
        (
            "How We Use Your Information",
            "We use the information we collect to provide our services, process donations, "
                + "communicate with you about our programs, and fulfill our non-profit mission "
                + "of expanding access to justice. We do not sell your personal information to "
                + "third parties."
        ),
        (
            "Attorney-Client Privilege",
            "Communications with attorneys through our Legal Aid program are protected by "
                + "attorney-client privilege to the fullest extent permitted by law. We do not "
                + "disclose confidential client communications without your consent."
        ),
        (
            "Donor Privacy",
            "We respect the privacy of our donors. We do not share, sell, rent, or trade donor "
                + "information with other organizations. Donor records are kept confidential and "
                + "are only used internally for the purposes of administering donations and "
                + "keeping donors informed about our work."
        ),
        (
            "Contact Us",
            "If you have questions about this Privacy Policy, please contact us at "
                + "support@neonlaw.org."
        ),
    ]

    var body: some HTML {
        PageLayout(
            pageTitle: "Privacy Policy",
            pageDescription: "Privacy Policy for the Neon Law Foundation.",
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-3xl font-bold text-gray-900 mb-8")) { "Privacy Policy" }
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

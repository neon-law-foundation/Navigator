import Elementary
import NavigatorWeb

/// The public homepage for the Neon Law Foundation.
struct HomePage: HTML {
    let brand: any Brand

    var body: some HTML {
        PageLayout(
            pageTitle: "Home",
            pageDescription: "Closing the Justice Gap with AI and Automation.",
            brand: brand
        ) {
            HeroSection(brand: brand)
            ProblemSection(brand: brand)
            ApproachSection(brand: brand)
            SupportSection(brand: brand)
        }
    }
}

private struct HeroSection: HTML {
    let brand: any Brand

    var body: some HTML {
        section(.class("bg-gradient-to-r from-cyan-50 to-cyan-100 py-16 sm:py-28")) {
            div(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 text-center")) {
                h1(.class("text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 mb-6")) {
                    "Closing the Justice Gap with AI and Automation"
                }
                p(.class("text-xl text-gray-600 mb-4 font-medium")) {
                    "Open-source legal software and hands-on AI training for attorneys"
                }
                p(.class("text-lg text-gray-700 mb-10 max-w-2xl mx-auto")) {
                    "The Neon Law Foundation is a 501(c)(3) nonprofit pursuing a dual mission: "
                    "building open-source legal software like Navigator, and running hands-on AI "
                    "skills labs that train attorneys to tackle the legal challenges of tomorrow."
                }
                div(.class("flex flex-col sm:flex-row gap-4 justify-center")) {
                    a(
                        .href("/workshops/genai-training"),
                        .class("text-white px-8 py-4 rounded-lg font-semibold text-lg"),
                        .style("background-color:\(brand.primaryColor)")
                    ) { "Join the AI Skills Lab" }
                    a(
                        .href("/education"),
                        .class("border-2 px-8 py-4 rounded-lg font-semibold text-lg"),
                        .style("border-color:\(brand.primaryColor);color:\(brand.primaryColor)")
                    ) { "CLE Programs" }
                    a(
                        .href("/blog"),
                        .class("border-2 px-8 py-4 rounded-lg font-semibold text-lg"),
                        .style("border-color:\(brand.primaryColor);color:\(brand.primaryColor)")
                    ) { "Read the Blog" }
                }
            }
        }
    }
}

private struct ProblemSection: HTML {
    let brand: any Brand

    private let stats: [(stat: String, desc: String)] = [
        (
            "92%",
            "of civil legal problems faced by low-income Americans received inadequate or no "
                + "legal help (LSC Justice Gap Report, 2022)."
        ),
        (
            "5.1B",
            "people worldwide lack meaningful access to justice (World Justice Project, 2023)."
        ),
        (
            "86%",
            "of civil legal problems reported by low-income Americans in the prior year "
                + "received inadequate or no legal help (LSC, 2022)."
        ),
    ]

    var body: some HTML {
        section(.class("py-16 sm:py-24 bg-white")) {
            div(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8")) {
                div(.class("grid grid-cols-1 md:grid-cols-2 gap-12 items-center")) {
                    div {
                        h2(.class("text-3xl font-bold text-gray-900 mb-6")) {
                            "The Access to Justice Crisis"
                        }
                        p(.class("text-gray-700 text-lg mb-6")) {
                            "According to the Legal Services Corporation's 2022 Justice Gap study, "
                            "92% of civil legal problems faced by low-income Americans received "
                            "inadequate or no legal help. That means millions of people navigate "
                            "evictions, custody disputes, and debt collection alone."
                        }
                        p(.class("text-gray-700 text-lg mb-8")) {
                            "The World Justice Project's 2023 Rule of Law Index found that 5.1 "
                            "billion people worldwide lack meaningful access to justice. AI and "
                            "automation can help legal professionals serve far more clients "
                            "without sacrificing quality."
                        }
                    }
                    div(.class("space-y-4")) {
                        for item in stats {
                            div(.class("bg-cyan-50 rounded-lg p-6 border border-cyan-100")) {
                                h3(
                                    .class("font-bold text-2xl mb-2"),
                                    .style("color:\(brand.primaryColor)")
                                ) { item.stat }
                                p(.class("text-gray-600 text-sm")) { item.desc }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ApproachSection: HTML {
    let brand: any Brand

    private let pillars: [(title: String, desc: String)] = [
        (
            "AI-Assisted Legal Research",
            "Train attorneys to use AI tools responsibly for research and drafting while meeting "
                + "professional responsibility obligations."
        ),
        (
            "Workflow Automation",
            "Teach legal professionals to automate repetitive tasks so they can focus on the "
                + "complex work that requires human judgment."
        ),
        (
            "Expanding Legal Aid Capacity",
            "Help legal aid organizations and pro bono attorneys serve more clients with the "
                + "same resources through technology."
        ),
    ]

    var body: some HTML {
        section(.class("py-16 sm:py-24 bg-gray-50")) {
            div(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8")) {
                h2(.class("text-3xl font-bold text-gray-900 mb-4 text-center")) {
                    "Training Attorneys for Tomorrow"
                }
                p(.class("text-gray-600 text-center mb-12 text-lg max-w-2xl mx-auto")) {
                    "Our CLE programs equip legal professionals with AI and automation skills to "
                    "serve more clients, reduce costs, and deliver competent representation at scale."
                }
                div(.class("grid grid-cols-1 sm:grid-cols-3 gap-6")) {
                    for pillar in pillars {
                        div(.class("bg-white rounded-lg p-6 border border-gray-100 shadow-sm")) {
                            h3(.class("font-semibold text-gray-900 mb-3")) { pillar.title }
                            p(.class("text-gray-600 text-sm")) { pillar.desc }
                        }
                    }
                }
                div(.class("text-center mt-10")) {
                    a(
                        .href("/education"),
                        .class("font-semibold hover:underline"),
                        .style("color:\(brand.primaryColor)")
                    ) { "Browse CLE programs \u{2192}" }
                }
            }
        }
    }
}

private struct SupportSection: HTML {
    let brand: any Brand

    var body: some HTML {
        section(.id("contact"), .class("py-16 sm:py-24 bg-white")) {
            div(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 text-center")) {
                h2(.class("text-3xl font-bold text-gray-900 mb-4")) {
                    "Support the Foundation"
                }
                p(.class("text-gray-600 mb-10 text-lg max-w-xl mx-auto")) {
                    "The Neon Law Foundation is a 501(c)(3) nonprofit. Contributions fund legal "
                    "education, AI-powered access to justice tools, and training programs that "
                    "help attorneys serve underrepresented communities."
                }
                div(.class("flex flex-col sm:flex-row gap-6 justify-center")) {
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

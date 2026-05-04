import Elementary
import NavigatorWeb

/// The `/navigator` page explains the Navigator open standard.
struct NavigatorPage: HTML {
    let brand: any Brand

    var body: some HTML {
        PageLayout(
            pageTitle: "Navigator",
            pageDescription:
                "An open standard for encoding legal workflows as deterministic, auditable processes.",
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-4xl font-bold text-gray-900 mb-4")) { "Navigator" }
                p(.class("text-lg text-gray-600 mb-4")) {
                    "An open standard for encoding legal workflows as deterministic, auditable processes."
                }
                div(.class("flex gap-4 mb-12")) {
                    a(
                        .href("https://github.com/neon-law-foundation/Navigator"),
                        .class("font-medium hover:underline"),
                        .style("color:\(brand.primaryColor)"),
                        .target(.blank),
                        .rel("noopener noreferrer")
                    ) {
                        "github.com/neon-law-foundation/Navigator \u{2192}"
                    }
                }
                section(.class("mb-12")) {
                    h2(.class("text-2xl font-bold text-gray-900 mb-4")) { "What Navigator Is" }
                    p(.class("text-gray-700 leading-relaxed mb-4")) {
                        "Navigator is a specification for structuring legal work as reproducible "
                        "workflows. It defines three core primitives \u{2014} Templates, Notations, "
                        "and State Machines \u{2014} that together encode the full lifecycle of a "
                        "legal matter from intake to delivery."
                    }
                    p(.class("text-gray-700 leading-relaxed")) {
                        "Any legal professional can adopt Navigator. The format is plain Markdown "
                        "and YAML. No proprietary software required."
                    }
                }
                section(.class("mb-12")) {
                    h2(.class("text-2xl font-bold text-gray-900 mb-6")) { "Core Components" }
                    div(.class("space-y-8")) {
                        NavigatorPrimitive(
                            title: "Templates",
                            summary:
                                "A Template is a single Markdown file that contains three things: "
                                + "a client questionnaire, a staff review workflow, and a document "
                                + "body. Document bodies use Liquid templating \u{2014} questionnaire "
                                + "answers are substituted at render time to produce the final "
                                + "document.",
                            brand: brand
                        )
                        NavigatorPrimitive(
                            title: "Notations",
                            summary:
                                "A Notation is a live instance of a Template \u{2014} one per client "
                                + "engagement. It holds the client's questionnaire answers and "
                                + "tracks the current lifecycle state.",
                            brand: brand
                        )
                        NavigatorPrimitive(
                            title: "State Machines",
                            summary:
                                "State Machines define the valid transitions between Notation "
                                + "states. They are finite paths with explicit entry conditions, "
                                + "preventing a Notation from skipping required steps or moving "
                                + "backward unexpectedly.",
                            brand: brand
                        )
                    }
                }
            }
        }
    }
}

private struct NavigatorPrimitive: HTML {
    let title: String
    let summary: String
    let brand: any Brand

    var body: some HTML {
        div(
            .class("pl-6 border-l-4"),
            .style("border-color:\(brand.primaryColor)")
        ) {
            h3(.class("text-xl font-semibold text-gray-900 mb-3")) { title }
            p(.class("text-gray-700 leading-relaxed")) { summary }
        }
    }
}

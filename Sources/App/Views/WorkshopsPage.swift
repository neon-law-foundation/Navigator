import Elementary
import NavigatorWeb

/// The `/workshops/genai-training` page — landing page for the
/// Foundation's one-hour hands-on workshop: *Claude Code + Twelve
/// Zodiac Lawyers*.
struct WorkshopsPage: HTML {
    let brand: any Brand
    let materials: [WorkshopMaterial]

    private let agenda: [(time: String, title: String, desc: String)] = [
        (
            "0:00\u{2013}0:20", "Install Claude Code",
            "Install the Claude Code CLI, authenticate against Anthropic, and verify with a "
                + "scratch-directory prompt. Everyone ends this block with a working shell."
        ),
        (
            "0:20\u{2013}0:55", "Twelve Zodiac Lawyers",
            "Run the sample operating agreement through four to six persona prompts. Each "
                + "persona reviews the contract in a different temperament and output format."
        ),
        (
            "0:55\u{2013}1:00", "Debrief",
            "Compare the persona outputs side-by-side. Which issues did every persona catch? "
                + "Which did only one catch? That divergence is the point."
        ),
    ]

    private let prerequisites: [String] = [
        "A laptop with a working macOS, Linux, or Windows-with-WSL shell.",
        "Willingness to install Claude Code locally (instructions in the runbook).",
        "An Anthropic account. Free-tier access is enough for the exercise.",
        "No prior Claude Code experience required.",
    ]

    private let objectives: [(level: String, objective: String)] = [
        (
            "Apply",
            "Install and authenticate Claude Code, then run a working prompt against a local file."
        ),
        (
            "Analyze",
            "Dissect a sample operating agreement through multiple review lenses, producing "
                + "structured output per persona."
        ),
        (
            "Evaluate",
            "Compare persona outputs at debrief and judge which review angles materially "
                + "improved coverage versus a single-prompt review."
        ),
    ]

    var body: some HTML {
        PageLayout(
            pageTitle: "Claude Code + Twelve Zodiac Lawyers",
            pageDescription:
                "A one-hour hands-on workshop: install Claude Code, then review a sample "
                + "operating agreement through twelve attorney personas.",
            brand: brand
        ) {
            Hero(brand: brand)
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                PrerequisitesSection(items: prerequisites)
                AgendaSection(brand: brand, agenda: agenda)
                ObjectivesSection(objectives: objectives)
                DownloadsSection(brand: brand, materials: materials)
                ScheduleSection(brand: brand)
            }
        }
    }
}

private struct Hero: HTML {
    let brand: any Brand

    var body: some HTML {
        section(.class("bg-gradient-to-r from-cyan-50 to-cyan-100 py-16 sm:py-20")) {
            div(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center")) {
                p(
                    .class("text-sm font-semibold uppercase tracking-wide mb-3"),
                    .style("color:\(brand.primaryColor)")
                ) { "AI Skills Lab \u{2014} one-hour workshop" }
                h1(.class("text-4xl sm:text-5xl font-bold text-gray-900 mb-4")) {
                    "Claude Code + Twelve Zodiac Lawyers"
                }
                p(.class("text-lg text-gray-700 max-w-2xl mx-auto")) {
                    "Install Claude Code live, then put it to work: twelve attorney personas "
                    "review the same sample operating agreement and surface a wider spread of "
                    "issues than any single reviewer would."
                }
            }
        }
    }
}

private struct PrerequisitesSection: HTML {
    let items: [String]

    var body: some HTML {
        section(.class("mb-12")) {
            h2(.class("text-2xl font-bold text-gray-900 mb-4")) { "Prerequisites" }
            ul(.class("list-disc pl-6 space-y-2 text-gray-700")) {
                for item in items {
                    li { item }
                }
            }
        }
    }
}

private struct AgendaSection: HTML {
    let brand: any Brand
    let agenda: [(time: String, title: String, desc: String)]

    var body: some HTML {
        section(.class("mb-12")) {
            h2(.class("text-2xl font-bold text-gray-900 mb-6")) { "One-Hour Agenda" }
            div(.class("space-y-4")) {
                for slot in agenda {
                    div(.class("border border-gray-100 rounded-xl p-6 shadow-sm")) {
                        div(.class("flex flex-wrap items-baseline gap-3 mb-2")) {
                            span(
                                .class("text-sm font-mono px-2 py-1 rounded"),
                                .style(
                                    "color:\(brand.primaryColor);"
                                        + "background-color:\(brand.primaryColor)14"
                                )
                            ) { slot.time }
                            h3(.class("text-lg font-semibold text-gray-900")) { slot.title }
                        }
                        p(.class("text-gray-700")) { slot.desc }
                    }
                }
            }
        }
    }
}

private struct ObjectivesSection: HTML {
    let objectives: [(level: String, objective: String)]

    var body: some HTML {
        section(.class("mb-12")) {
            h2(.class("text-2xl font-bold text-gray-900 mb-4")) {
                "Learning Objectives"
            }
            p(.class("text-gray-700 mb-6")) {
                "Mapped to Bloom\u{2019}s Taxonomy cognitive levels so the agenda earns CLE "
                "credit and gives participants a clear arc."
            }
            div(.class("space-y-3")) {
                for item in objectives {
                    div(.class("flex gap-4")) {
                        span(
                            .class(
                                "shrink-0 inline-block w-24 text-sm font-semibold uppercase "
                                    + "tracking-wide text-gray-500 pt-1"
                            )
                        ) { item.level }
                        p(.class("text-gray-700")) { item.objective }
                    }
                }
            }
        }
    }
}

private struct DownloadsSection: HTML {
    let brand: any Brand
    let materials: [WorkshopMaterial]

    var body: some HTML {
        section(.class("mb-12")) {
            h2(.class("text-2xl font-bold text-gray-900 mb-4")) { "Download the Materials" }
            p(.class("text-gray-700 mb-6")) {
                "All three documents are plain Markdown. Open each one to copy the raw source "
                "straight into Claude Code, or grab the file for `curl`/`wget`."
            }
            div(.class("space-y-4")) {
                for material in materials {
                    div(.class("border border-gray-100 rounded-xl p-5")) {
                        a(
                            .href("/workshops/genai-training/\(material.slug)"),
                            .class("font-semibold hover:underline"),
                            .style("color:\(brand.primaryColor)")
                        ) { material.title }
                        p(.class("text-gray-600 text-sm mt-1")) { material.description }
                    }
                }
            }
        }
    }
}

private struct ScheduleSection: HTML {
    let brand: any Brand

    var body: some HTML {
        section {
            h2(.class("text-2xl font-bold text-gray-900 mb-4")) { "Schedule a Workshop" }
            p(.class("text-gray-700 mb-6")) {
                "We run this workshop for bar associations, legal aid organizations, law "
                "schools, and law firms. Reach out to book a session for your team."
            }
            a(
                .href("mailto:support@neonlaw.org?subject=Workshop Inquiry"),
                .class("inline-block px-6 py-3 rounded-lg font-semibold text-white"),
                .style("background-color:\(brand.primaryColor)")
            ) { "Email us to schedule" }
        }
    }
}

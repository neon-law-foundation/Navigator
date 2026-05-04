import Elementary
import NavigatorWeb

/// The `/education` page — lists CLE offerings.
struct EducationPage: HTML {
    let brand: any Brand

    private let courses: [CLECourse] = [
        CLECourse(
            title: "Citation Verification",
            level: "1.0 CLE Credit",
            description:
                "Legal citations are the foundation of every brief and memo \u{2014} and they fail "
                + "more often than practitioners realize. This module covers verification "
                + "workflows, tools that check citations automatically, and how to document "
                + "your review process so it stands up to scrutiny.",
            topics: [
                "Why citations fail and how to catch errors before filing",
                "Automated citation checking tools and their limitations",
                "Manual verification workflows for critical citations",
                "Documenting your verification process for malpractice protection",
            ]
        ),
        CLECourse(
            title: "Safe Use of AI Tools in Legal Practice",
            level: "1.5 CLE Credits",
            description:
                "AI tools can accelerate legal research and drafting \u{2014} but they hallucinate, "
                + "misstate law, and produce confident-sounding errors. This module teaches a "
                + "verification-first approach to AI-assisted legal work that satisfies "
                + "professional responsibility obligations.",
            topics: [
                "How large language models produce plausible-but-wrong legal output",
                "Which tasks AI is safe to use for and which require full human review",
                "Competence obligations under Model Rules 1.1 and 5.3",
                "Building a verification checklist for AI-assisted research",
                "Disclosure obligations when using AI in client work",
            ]
        ),
        CLECourse(
            title: "AI and Automation for Access to Justice",
            level: "1.0 CLE Credit",
            description:
                "The LSC Justice Gap Report found that 92% of civil legal problems faced by "
                + "low-income Americans received inadequate or no legal help. This module "
                + "teaches attorneys how to use AI and workflow automation to expand their "
                + "capacity and serve more clients \u{2014} especially in legal aid and pro bono "
                + "settings.",
            topics: [
                "The access to justice crisis: scope, causes, and what attorneys can do",
                "Using AI to automate intake, triage, and document assembly",
                "Building repeatable workflows that reduce time per case",
                "Scaling pro bono impact with AI-assisted research tools",
                "Ethical obligations when deploying automation in client-facing work",
            ]
        ),
    ]

    var body: some HTML {
        PageLayout(
            pageTitle: "Legal Education",
            pageDescription:
                "CLE programs that train attorneys to use AI and automation to expand access to "
                + "justice and serve more clients.",
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-4xl font-bold text-gray-900 mb-4")) { "Legal Education" }
                p(.class("text-lg text-gray-600 mb-12")) {
                    "CLE programs that train attorneys to use AI and automation responsibly \u{2014} "
                    "so they can serve more clients, reduce costs, and expand access to justice."
                }
                section(.class("mb-16")) {
                    h2(.class("text-2xl font-bold text-gray-900 mb-8")) {
                        "Continuing Legal Education"
                    }
                    div(.class("space-y-10")) {
                        for course in courses {
                            CLECourseCard(course: course, brand: brand)
                        }
                    }
                }
            }
        }
    }
}

struct CLECourse: Sendable {
    let title: String
    let level: String
    let description: String
    let topics: [String]
}

private struct CLECourseCard: HTML {
    let course: CLECourse
    let brand: any Brand

    var body: some HTML {
        div(.class("border border-gray-100 rounded-xl p-8 shadow-sm")) {
            div(.class("flex items-start justify-between gap-4 mb-4")) {
                h3(.class("text-xl font-semibold text-gray-900")) { course.title }
                span(
                    .class("text-sm font-medium px-3 py-1 rounded-full whitespace-nowrap"),
                    .style(
                        "color:\(brand.primaryColor);background-color:\(brand.primaryColor)14"
                    )
                ) { course.level }
            }
            p(.class("text-gray-700 leading-relaxed mb-6")) { course.description }
            div {
                p(.class("text-sm font-semibold text-gray-900 mb-3")) { "Topics covered:" }
                ul(.class("space-y-2")) {
                    for topic in course.topics {
                        li(.class("flex items-start gap-2")) {
                            span(
                                .class("font-bold mt-0.5 text-sm"),
                                .style("color:\(brand.primaryColor)")
                            ) { "\u{2022}" }
                            span(.class("text-gray-700 text-sm")) { topic }
                        }
                    }
                }
            }
        }
    }
}

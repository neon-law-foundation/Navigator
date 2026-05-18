import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/templates` — read-only list of every template version.
///
/// Templates are sourced from git repositories and versioned by commit SHA;
/// admin operators cannot create one through the UI. The index renders a
/// row per version with a deep link to the version-specific show page.
struct TemplatesIndexPage: HTML {
    let brand: any Brand
    let templates: [Template]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Templates",
            activeSection: .templates,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(templates.count) version\(templates.count == 1 ? "" : "s")"
                }
                p(.class("text-xs text-gray-500")) {
                    "Templates are sourced from git; create a new version by committing to the source repository."
                }
            }
            if templates.isEmpty {
                div(
                    .class(
                        "rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white"
                    )
                ) {
                    p(.class("text-gray-600")) { "No templates yet." }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Title")
                                AdminTableHeader("Code")
                                AdminTableHeader("Respondent")
                                AdminTableHeader("Version")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for t in templates {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/templates/\(t.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { t.title }
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-700")) {
                                        t.code ?? "\u{2014}"
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        t.respondentType.rawValue
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        String(t.version.prefix(8))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// `/admin/templates/:id` — read-only detail.
struct TemplateShowPage: HTML {
    let brand: any Brand
    let template: Template

    var body: some HTML {
        AdminPageLayout(
            pageTitle: template.title,
            activeSection: .templates,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/templates"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to templates"
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Title" }
                    dd(.class("text-gray-900")) { template.title }
                    dt(.class("text-gray-500")) { "Code" }
                    dd(.class("font-mono text-gray-900")) { template.code ?? "\u{2014}" }
                    dt(.class("text-gray-500")) { "Description" }
                    dd(.class("text-gray-900")) { template.description }
                    dt(.class("text-gray-500")) { "Respondent type" }
                    dd(.class("text-gray-900")) { template.respondentType.rawValue }
                    dt(.class("text-gray-500")) { "Version" }
                    dd(.class("font-mono text-gray-900 break-all")) { template.version }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Markdown content" }
                pre(
                    .class("text-xs bg-gray-50 p-4 rounded overflow-x-auto text-gray-800")
                ) { template.markdownContent }
            }
        }
    }
}

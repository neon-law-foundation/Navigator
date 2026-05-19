import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// `/admin/projects/:id/print` — chrome-free project summary suitable for
/// printing or saving as a PDF.
///
/// Unlike ``ProjectShowPage`` this page renders its own `<head>` and does
/// not wrap the body in the admin sidebar layout. The Tailwind CDN is
/// still loaded so the typography matches the rest of the portal when an
/// operator views the page before printing; the inline `<style>`
/// suppresses the in-page "Print" / "Back to portal" controls when the
/// document is sent to the printer (the controls only exist to drive the
/// browser's print dialog and shouldn't appear on the paper output).
struct ProjectPrintPage: HTMLDocument {
    let brand: any Brand
    let project: Project
    let assignments: [PersonProjectRole]
    let documents: [Document]
    let gitRepositories: [GitRepository]
    let activity: [AdminActivityEvent]

    var title: String { "\(project.codename) - \(brand.name) Print" }
    var lang: String { "en" }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        meta(.name("robots"), .content("noindex, nofollow"))
        link(.rel(.icon), .href("/favicon.svg"))
        script(.src("https://cdn.tailwindcss.com")) {}
        style {
            """
            @media print {
                .no-print { display: none !important; }
                body { background: white !important; }
            }
            """
        }
    }

    var body: some HTML {
        div(
            .class("max-w-3xl mx-auto py-8 px-6 bg-white text-gray-900"),
            .custom(name: "data-page", value: "project-print")
        ) {
            div(
                .class("flex items-center justify-between mb-8 no-print"),
                .custom(name: "data-section", value: "print-controls")
            ) {
                a(
                    .href("/admin/projects/\(project.id?.uuidString ?? "")"),
                    .class("text-sm text-gray-600 hover:underline")
                ) {
                    "\u{2190} Back to project"
                }
                button(
                    .type(.button),
                    .class("rounded bg-indigo-600 text-white text-sm px-3 py-1.5"),
                    .custom(name: "onclick", value: "window.print()")
                ) { "Print" }
            }
            header(.class("border-b border-gray-300 pb-4 mb-6")) {
                p(.class("text-xs uppercase tracking-wide text-gray-500")) { brand.name }
                h1(.class("text-3xl font-bold text-gray-900")) { project.codename }
                if let title = project.title {
                    p(.class("text-base text-gray-700 mt-1")) { title }
                }
            }
            section(.class("mb-6"), .custom(name: "data-section", value: "details")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-2")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-2 text-sm")) {
                    dt(.class("text-gray-500")) { "Codename" }
                    dd(.class("font-mono text-gray-900")) { project.codename }
                    dt(.class("text-gray-500")) { "Status" }
                    dd(.class("text-gray-900")) { project.status?.rawValue ?? "\u{2014}" }
                    dt(.class("text-gray-500")) { "Type" }
                    dd(.class("text-gray-900")) { project.projectType?.rawValue ?? "\u{2014}" }
                }
            }
            section(.class("mb-6"), .custom(name: "data-section", value: "people")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-2")) { "People" }
                if assignments.isEmpty {
                    p(.class("text-sm text-gray-500")) { "None." }
                } else {
                    ul(.class("text-sm space-y-1")) {
                        for assignment in assignments {
                            li(
                                .custom(
                                    name: "data-person-id",
                                    value: assignment.$person.id.uuidString
                                )
                            ) {
                                span(.class("text-gray-900")) { assignment.person.name }
                                span(.class("text-gray-500")) {
                                    " — \(assignment.role.rawValue)"
                                }
                            }
                        }
                    }
                }
            }
            section(.class("mb-6"), .custom(name: "data-section", value: "documents")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-2")) { "Documents" }
                if documents.isEmpty {
                    p(.class("text-sm text-gray-500")) { "None." }
                } else {
                    ul(.class("text-sm space-y-1")) {
                        for doc in documents {
                            li(
                                .custom(
                                    name: "data-document-id",
                                    value: doc.id?.uuidString ?? ""
                                )
                            ) {
                                span(.class("text-gray-900")) { doc.title }
                            }
                        }
                    }
                }
            }
            section(.class("mb-6"), .custom(name: "data-section", value: "git")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-2")) { "Git repositories" }
                if gitRepositories.isEmpty {
                    p(.class("text-sm text-gray-500")) { "None linked." }
                } else {
                    ul(.class("text-sm font-mono space-y-1")) {
                        for repo in gitRepositories {
                            li { repo.repositoryName }
                        }
                    }
                }
            }
            section(.custom(name: "data-section", value: "activity")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-2")) { "Activity" }
                if activity.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No activity recorded." }
                } else {
                    ol(.class("text-sm space-y-2")) {
                        for event in activity {
                            li(.custom(name: "data-kind", value: event.kind)) {
                                p(.class("text-gray-900")) { event.description }
                                p(.class("text-xs font-mono text-gray-500")) {
                                    Self.formatter.string(from: event.timestamp)
                                }
                            }
                        }
                    }
                }
            }
            footer(.class("mt-10 pt-4 border-t border-gray-300 text-xs text-gray-500")) {
                p {
                    "Generated \(Self.formatter.string(from: Date())) UTC · "
                        + "\(brand.name) Navigator"
                }
            }
        }
    }
}

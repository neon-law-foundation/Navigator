import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/notations` — read-only list. Each row is one assignment of a
/// template to a respondent.
struct NotationsIndexPage: HTML {
    let brand: any Brand
    let notations: [Notation]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Notations",
            activeSection: .notations,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(notations.count) notation\(notations.count == 1 ? "" : "s")"
                }
                p(.class("text-xs text-gray-500")) {
                    "Notations are created by the API and the workflow engine; the admin view is read-only."
                }
            }
            if notations.isEmpty {
                div(
                    .class(
                        "rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white"
                    )
                ) {
                    p(.class("text-gray-600")) { "No notations yet." }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Template")
                                AdminTableHeader("Respondent")
                                AdminTableHeader("State")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for n in notations {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/notations/\(n.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { n.template.title }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        respondentLabel(for: n)
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        n.stateHistory.value.last?.toState ?? "(none)"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Renders the right side of a notation row — the respondent. A
    /// notation may target a person, an entity, or both depending on its
    /// template's respondent type.
    private func respondentLabel(for notation: Notation) -> String {
        let parts: [String] = [
            notation.person.map { "Person: \($0.name)" } ?? "",
            notation.entity.map { "Entity: \($0.name)" } ?? "",
        ].filter { !$0.isEmpty }
        return parts.isEmpty ? "(unassigned)" : parts.joined(separator: " / ")
    }
}

struct NotationShowPage: HTML {
    let brand: any Brand
    let notation: Notation

    var body: some HTML {
        AdminPageLayout(
            pageTitle: notation.template.title,
            activeSection: .notations,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/notations"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to notations"
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Template" }
                    dd(.class("text-gray-900")) { notation.template.title }
                    if let person = notation.person {
                        dt(.class("text-gray-500")) { "Person" }
                        dd(.class("text-gray-900")) {
                            a(.href("/admin/people/\(person.id?.uuidString ?? "")")) { person.name }
                        }
                    }
                    if let entity = notation.entity {
                        dt(.class("text-gray-500")) { "Entity" }
                        dd(.class("text-gray-900")) {
                            a(.href("/admin/entities/\(entity.id?.uuidString ?? "")")) { entity.name }
                        }
                    }
                    dt(.class("text-gray-500")) { "Current state" }
                    dd(.class("font-mono text-gray-900")) {
                        notation.stateHistory.value.last?.toState ?? "(none)"
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "State history" }
                if notation.stateHistory.value.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No transitions recorded yet." }
                } else {
                    ol(.class("space-y-2 text-sm font-mono")) {
                        for event in notation.stateHistory.value {
                            li {
                                "\(event.fromState) \u{2192} \(event.toState)"
                            }
                        }
                    }
                }
            }
        }
    }
}

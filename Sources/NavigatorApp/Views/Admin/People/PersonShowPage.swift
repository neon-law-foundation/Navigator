import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/people/:id` — detail for a single person.
struct PersonShowPage: HTML {
    let brand: any Brand
    let person: Person
    let projectAssignments: [PersonProjectRole]
    let entityRoles: [PersonEntityRole]

    private var personID: String { person.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: person.name,
            activeSection: .people,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/people"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to people"
                }
                LinkButton("Edit", href: "/admin/people/\(personID)/edit", variant: .primary)
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Name" }
                    dd(.class("text-gray-900")) { person.name }
                    dt(.class("text-gray-500")) { "Email" }
                    dd(.class("text-gray-900")) { person.email }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Project assignments" }
                if projectAssignments.isEmpty {
                    p(.class("text-sm text-gray-500")) {
                        "Not currently assigned to any project."
                    }
                } else {
                    ul(.class("space-y-2 text-sm")) {
                        for assignment in projectAssignments {
                            li(.custom(name: "data-role", value: assignment.role.rawValue)) {
                                a(
                                    .href("/admin/projects/\(assignment.$project.id.uuidString)"),
                                    .class("text-indigo-700 hover:underline font-mono")
                                ) { assignment.project.codename }
                                span(.class("text-gray-500")) { " — \(assignment.role.rawValue)" }
                            }
                        }
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Entity roles" }
                if entityRoles.isEmpty {
                    p(.class("text-sm text-gray-500")) {
                        "No entity memberships recorded."
                    }
                } else {
                    ul(.class("space-y-2 text-sm")) {
                        for role in entityRoles {
                            li(.custom(name: "data-role", value: role.role.rawValue)) {
                                a(
                                    .href("/admin/entities/\(role.$entity.id.uuidString)"),
                                    .class("text-indigo-700 hover:underline")
                                ) { role.entity.name }
                                span(.class("text-gray-500")) { " — \(role.role.rawValue)" }
                            }
                        }
                    }
                }
            }
        }
    }
}

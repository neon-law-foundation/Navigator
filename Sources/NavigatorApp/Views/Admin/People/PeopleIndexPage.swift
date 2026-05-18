import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/people` — list of every person in the directory.
struct PeopleIndexPage: HTML {
    let brand: any Brand
    let people: [Person]
    let flash: String?

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "People",
            activeSection: .people,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(people.count) \(people.count == 1 ? "person" : "people")"
                }
                LinkButton("New person", href: "/admin/people/new", variant: .primary)
            }
            if let flash {
                div(
                    .class("mb-4 rounded-md border border-green-300 bg-green-50 p-3 text-sm text-green-800"),
                    .custom(name: "role", value: "status")
                ) { flash }
            }
            if people.isEmpty {
                div(
                    .class("rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white")
                ) {
                    p(.class("text-gray-600")) { "No people yet. " }
                    a(.href("/admin/people/new"), .class("text-indigo-600 hover:underline")) {
                        "Add the first one."
                    }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Name")
                                AdminTableHeader("Email")
                                AdminTableHeader("")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for person in people {
                                tr(.custom(name: "data-person-id", value: person.id?.uuidString ?? "")) {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/people/\(person.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { person.name }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { person.email }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/people/\(person.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
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

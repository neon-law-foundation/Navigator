import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Project assignments", .serialized)
struct AdminProjectAssignmentsTests {

    private func seed(
        db: Database,
        codename: String
    ) async throws -> (project: Project, person: Person) {
        let project = Project()
        project.codename = codename
        try await project.save(on: db)
        let person = Person()
        person.name = "Assign Test"
        person.email = "assign-\(UUID().uuidString.prefix(6))@example.com"
        try await person.save(on: db)
        return (project, person)
    }

    @Test("project show renders the assign-a-person form")
    func projectShowHasAssignForm() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (project, _) = try await seed(db: db, codename: "ppr-\(UUID().uuidString.prefix(4))")
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("Assign a person"))
                    #expect(body.contains(#"name="personId""#))
                    #expect(body.contains(#"name="role""#))
                }
            )
        }
    }

    @Test("POST creates an assignment row")
    func postCreatesAssignment() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (project, person) = try await seed(
                db: db,
                codename: "ppr2-\(UUID().uuidString.prefix(4))"
            )
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/assignments",
                beforeRequest: { req in
                    try req.content.encode(
                        ["personId": person.id!.uuidString, "role": "staff"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let row = try await PersonProjectRole.query(on: db)
                .filter(\.$person.$id == person.id!)
                .filter(\.$project.$id == project.id!)
                .first()
            #expect(row?.role == .staff)
        }
    }

    @Test("POST rejects duplicate assignment for the same person")
    func postRejectsDuplicate() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (project, person) = try await seed(
                db: db,
                codename: "ppr3-\(UUID().uuidString.prefix(4))"
            )
            let existing = PersonProjectRole()
            existing.$person.id = person.id!
            existing.$project.id = project.id!
            existing.role = .client
            try await existing.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/assignments",
                beforeRequest: { req in
                    try req.content.encode(
                        ["personId": person.id!.uuidString, "role": "staff"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    let location = res.headers.first(name: .location) ?? ""
                    #expect(location.contains("assignment_error="))
                }
            )
            let count = try await PersonProjectRole.query(on: db)
                .filter(\.$person.$id == person.id!)
                .filter(\.$project.$id == project.id!)
                .count()
            #expect(count == 1)
        }
    }

    @Test("DELETE removes an existing assignment")
    func deleteRemovesAssignment() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (project, person) = try await seed(
                db: db,
                codename: "ppr4-\(UUID().uuidString.prefix(4))"
            )
            let row = PersonProjectRole()
            row.$person.id = person.id!
            row.$project.id = project.id!
            row.role = .staff
            try await row.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/assignments/\(row.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            let reloaded = try await PersonProjectRole.find(row.id!, on: db)
            #expect(reloaded == nil)
        }
    }

    @Test("assigned people do not appear in the dropdown again")
    func dropdownExcludesAlreadyAssigned() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (project, person) = try await seed(
                db: db,
                codename: "ppr5-\(UUID().uuidString.prefix(4))"
            )
            let row = PersonProjectRole()
            row.$person.id = person.id!
            row.$project.id = project.id!
            row.role = .staff
            try await row.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    // The assigned person's name appears in the People
                    // section, but NOT inside the assign-a-person <select>
                    // — counting occurrences below 3 is the cheap proxy.
                    let count = body.components(separatedBy: person.name).count - 1
                    #expect(count == 1)
                }
            )
        }
    }
}

import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Project activity timeline", .serialized)
struct AdminProjectActivityTests {

    private func seedProject(
        db: Database,
        codename: String
    ) async throws -> Project {
        let p = Project()
        p.codename = codename
        try await p.save(on: db)
        return p
    }

    @Test("show page renders an Activity section with the created event")
    func activitySectionRendersCreatedEvent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(
                db: db,
                codename: "activity-\(UUID().uuidString.prefix(4))"
            )
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Activity<"))
                    #expect(body.contains(#"data-kind="created""#))
                    #expect(body.contains("Project \(project.codename) created."))
                }
            )
        }
    }

    @Test("PersonProjectRole insert shows up as a personAssigned event")
    func activitySurfacesAssignments() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(
                db: db,
                codename: "activity-pa-\(UUID().uuidString.prefix(4))"
            )
            let person = Person()
            person.name = "Activity Tester"
            person.email = "act-\(UUID().uuidString.prefix(6))@example.com"
            try await person.save(on: db)
            let role = PersonProjectRole()
            role.$person.id = person.id!
            role.$project.id = project.id!
            role.role = .staff
            try await role.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="personAssigned""#))
                    #expect(body.contains("Activity Tester assigned as staff."))
                }
            )
        }
    }

    @Test("activity timeline orders events newest-first")
    func activityOrdersNewestFirst() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(
                db: db,
                codename: "activity-order-\(UUID().uuidString.prefix(4))"
            )
            let person = Person()
            person.name = "Late Joiner"
            person.email = "late-\(UUID().uuidString.prefix(6))@example.com"
            try await person.save(on: db)
            let role = PersonProjectRole()
            role.$person.id = person.id!
            role.$project.id = project.id!
            role.role = .client
            try await role.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    // Both events present.
                    #expect(body.contains(#"data-kind="created""#))
                    #expect(body.contains(#"data-kind="personAssigned""#))
                    // Newest-first ordering: personAssigned (most recent)
                    // appears before created in the rendered HTML.
                    guard
                        let assignedRange = body.range(of: #"data-kind="personAssigned""#)?
                            .lowerBound,
                        let createdRange = body.range(of: #"data-kind="created""#)?.lowerBound
                    else {
                        Issue.record("Expected both kinds to render.")
                        return
                    }
                    #expect(assignedRange < createdRange)
                }
            )
        }
    }

    @Test("project with no related rows still renders the created event only")
    func bareProjectShowsOneEvent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(
                db: db,
                codename: "activity-bare-\(UUID().uuidString.prefix(4))"
            )
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    let createdCount =
                        body.components(separatedBy: #"data-kind="created""#).count - 1
                    let updatedCount =
                        body.components(separatedBy: #"data-kind="updated""#).count - 1
                    #expect(createdCount == 1)
                    #expect(updatedCount == 0)
                }
            )
        }
    }
}

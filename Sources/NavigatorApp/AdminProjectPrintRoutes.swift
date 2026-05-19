import FluentKit
import NavigatorDAL
import NavigatorWeb
import Vapor
import VaporElementary

/// `/admin/projects/:id/print` — a stripped, print-friendly snapshot of
/// one project.
///
/// Operators occasionally need to hand a project summary to a client or
/// file it in a paper folder. The standard show page renders the admin
/// chrome (sidebar, action buttons, embedded edit forms) which prints
/// poorly. This route produces a chrome-free page with only the project
/// fields, current people, documents listing, and recent activity — the
/// information a reader needs and nothing else.
///
/// Discovery is via direct URL today; the show page can grow a "Print"
/// link later without modifying this file.
func registerAdminProjectPrintRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "projects")

    group.get(":id", "print") { req -> HTMLResponse in
        guard
            let raw = req.parameters.get("id"),
            let id = UUID(uuidString: raw)
        else {
            throw Abort(.badRequest, reason: "Invalid project id.")
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        guard let project = try await ProjectRepository(database: db).find(id: id) else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        async let assignments = PersonProjectRole.query(on: db)
            .filter(\.$project.$id == id)
            .with(\.$person)
            .all()
        async let documents = Document.query(on: db)
            .filter(\.$project.$id == id)
            .all()
        async let repos = GitRepository.query(on: db)
            .filter(\.$project.$id == id)
            .all()
        let (assignmentList, documentList, repoList) = try await (assignments, documents, repos)
        let activity = try await loadProjectActivity(project: project, db: db)
        return HTMLResponse {
            ProjectPrintPage(
                brand: brand,
                project: project,
                assignments: assignmentList,
                documents: documentList,
                gitRepositories: repoList,
                activity: activity
            )
        }
    }
}

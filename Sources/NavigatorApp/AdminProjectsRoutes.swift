import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Registers the `/admin/projects/*` resource routes.
///
/// Follows the same Rails-shaped pattern every admin resource will share
/// — `index`, `new`, `create`, `show`, `edit`, `update`, `destroy` — so
/// once this file reads correctly the rest of the resources can copy the
/// shape and only swap the model.
func registerAdminProjectsRoutes(_ app: Application, brand: any Brand) {

    let group = app.grouped("admin", "projects")

    // Index
    group.get { req -> HTMLResponse in
        let projects = try await loadProjects(req: req)
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            ProjectsIndexPage(brand: brand, projects: projects, flash: flash)
        }
    }

    // New
    group.get("new") { _ -> HTMLResponse in
        HTMLResponse {
            ProjectFormPage(
                brand: brand,
                mode: .new,
                form: ProjectFormValues(),
                errors: .none
            )
        }
    }

    // Create
    group.post { req -> Response in
        let submitted = (try? req.content.decode(ProjectFormPayload.self)) ?? .empty
        let values = submitted.values
        let result = try await create(req: req, values: values)
        switch result {
        case .success(let project):
            let flash = encodeFlash("Project \(project.codename) created.")
            return req.redirect(to: "/admin/projects?flash=\(flash)", redirectType: .normal)
        case .failure(let errors):
            let html = HTMLResponse {
                ProjectFormPage(brand: brand, mode: .new, form: values, errors: errors)
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
    }

    // Show
    group.get(":id") { req -> HTMLResponse in
        let project = try await loadProject(req: req)
        let (assignments, documents, repos) = try await loadProjectAssociations(
            req: req,
            project: project
        )
        return HTMLResponse {
            ProjectShowPage(
                brand: brand,
                project: project,
                assignments: assignments,
                documents: documents,
                gitRepositories: repos
            )
        }
    }

    // Edit
    group.get(":id", "edit") { req -> HTMLResponse in
        let project = try await loadProject(req: req)
        return HTMLResponse {
            ProjectFormPage(
                brand: brand,
                mode: .edit(id: project.id?.uuidString ?? ""),
                form: ProjectFormValues(project: project),
                errors: .none
            )
        }
    }

    // Update (PATCH)
    group.on(.PATCH, ":id") { req -> Response in
        let project = try await loadProject(req: req)
        let submitted = (try? req.content.decode(ProjectFormPayload.self)) ?? .empty
        let values = submitted.values
        let result = try await update(req: req, project: project, values: values)
        switch result {
        case .success(let updated):
            let flash = encodeFlash("Project \(updated.codename) updated.")
            return req.redirect(to: "/admin/projects?flash=\(flash)", redirectType: .normal)
        case .failure(let errors):
            let html = HTMLResponse {
                ProjectFormPage(
                    brand: brand,
                    mode: .edit(id: project.id?.uuidString ?? ""),
                    form: values,
                    errors: errors
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
    }

    // Destroy (DELETE)
    group.on(.DELETE, ":id") { req -> Response in
        let project = try await loadProject(req: req)
        let codename = project.codename
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await ProjectRepository(database: db).delete(id: project.id!)
        let flash = encodeFlash("Project \(codename) deleted.")
        return req.redirect(to: "/admin/projects?flash=\(flash)", redirectType: .normal)
    }
}

/// Form payload posted by the new / edit forms.
///
/// Empty string sentinels are how the URL-encoded decoder represents an
/// unfilled optional, so the conversion to typed enums happens in
/// ``ProjectFormPayload/values``.
private struct ProjectFormPayload: Content {
    var codename: String?
    var title: String?
    var status: String?
    var projectType: String?

    static let empty = ProjectFormPayload(codename: nil, title: nil, status: nil, projectType: nil)

    var values: ProjectFormValues {
        ProjectFormValues(
            codename: codename ?? "",
            title: title ?? "",
            status: status ?? "",
            projectType: projectType ?? ""
        )
    }
}

private enum ProjectMutationResult {
    case success(Project)
    case failure(ProjectFormErrors)
}

private func create(
    req: Request,
    values: ProjectFormValues
) async throws -> ProjectMutationResult {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    let repo = ProjectRepository(database: db)
    let errors = await validate(values: values, repo: repo, existingID: nil)
    if errors.summary.isEmpty == false || errors.codename != nil {
        return .failure(errors)
    }
    let project = Project()
    apply(values: values, to: project)
    _ = try await repo.create(model: project)
    return .success(project)
}

private func update(
    req: Request,
    project: Project,
    values: ProjectFormValues
) async throws -> ProjectMutationResult {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    let repo = ProjectRepository(database: db)
    let errors = await validate(values: values, repo: repo, existingID: project.id)
    if errors.summary.isEmpty == false || errors.codename != nil {
        return .failure(errors)
    }
    apply(values: values, to: project)
    _ = try await repo.update(model: project)
    return .success(project)
}

private func validate(
    values: ProjectFormValues,
    repo: ProjectRepository,
    existingID: UUID?
) async -> ProjectFormErrors {
    var summary: [String] = []
    var codenameError: String? = nil

    let codename = values.codename.trimmingCharacters(in: .whitespacesAndNewlines)
    if codename.isEmpty {
        codenameError = "Codename is required."
        summary.append("Codename is required.")
    } else if let existing = try? await repo.findByCodename(codename), existing.id != existingID {
        codenameError = "Codename is already taken."
        summary.append("Codename is already taken.")
    }

    return ProjectFormErrors(
        codename: codenameError,
        summary: summary
    )
}

private func apply(values: ProjectFormValues, to project: Project) {
    project.codename = values.codename.trimmingCharacters(in: .whitespacesAndNewlines)
    let title = values.title.trimmingCharacters(in: .whitespacesAndNewlines)
    project.title = title.isEmpty ? nil : title
    project.status = values.statusEnum
    project.projectType = values.projectTypeEnum
}

private func loadProjects(req: Request) async throws -> [Project] {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    return try await Project.query(on: db)
        .sort(\.$codename, .ascending)
        .all()
}

private func loadProject(req: Request) async throws -> Project {
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
    return project
}

private func loadProjectAssociations(
    req: Request,
    project: Project
) async throws -> ([PersonProjectRole], [Document], [GitRepository]) {
    guard let projectID = project.id else {
        return ([], [], [])
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    async let assignments = PersonProjectRole.query(on: db)
        .filter(\.$project.$id == projectID)
        .with(\.$person)
        .all()
    async let documents = Document.query(on: db)
        .filter(\.$project.$id == projectID)
        .all()
    async let repos = GitRepository.query(on: db)
        .filter(\.$project.$id == projectID)
        .all()
    return try await (assignments, documents, repos)
}

/// Brings the ergonomic-but-repetitive `databaseService` precondition into
/// one place so each route handler can stay a single line of intent.
func requireDatabaseService(_ req: Request) throws -> DatabaseService {
    guard let service = req.application.databaseService else {
        throw Abort(.serviceUnavailable, reason: "Database unavailable.")
    }
    return service
}

/// URL-encodes a flash message for round-tripping through the query
/// string. The flash is rendered on the next page as a green banner.
func encodeFlash(_ message: String) -> String {
    message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
}

/// Reverses ``encodeFlash``. Decoder is lenient — a malformed flash just
/// renders as-is.
func decodeFlash(_ raw: String) -> String {
    raw.removingPercentEncoding ?? raw
}

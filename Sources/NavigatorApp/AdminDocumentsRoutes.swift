import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Routes that own document authoring on a project: upload (POST under
/// the project), download (streams the file), delete.
///
/// Upload writes through ``Application/documentStorage`` so tests can
/// swap the backend; production keeps the local-disk default.
func registerAdminDocumentsRoutes(_ app: Application, brand: any Brand) {
    // Upload nested under the project so the route URL captures the
    // project context the new row will link to.
    app.post("admin", "projects", ":id", "documents") { req -> Response in
        guard let raw = req.parameters.get("id"), let projectID = UUID(uuidString: raw) else {
            throw Abort(.badRequest, reason: "Invalid project id.")
        }
        let db = try await requireDatabaseService(req).db
        guard let project = try await Project.find(projectID, on: db) else {
            throw Abort(.notFound)
        }
        let payload = try? req.content.decode(DocumentUploadPayload.self)
        let trimmedTitle =
            (payload?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let payload, !trimmedTitle.isEmpty, payload.file.data.readableBytes > 0 else {
            let flash = encodeFlash("Title and a file are both required.")
            return req.redirect(
                to: "/admin/projects/\(project.id!.uuidString)?document_error=\(flash)",
                redirectType: .normal
            )
        }
        let url = try await req.application.documentStorage.write(
            payload.file.data,
            suggestedFilename: payload.file.filename
        )

        let documentID = UUID()
        let blob = Blob()
        blob.objectStorageUrl = url
        blob.referencedBy = .documents
        blob.referencedById = documentID
        try await blob.save(on: db)

        let document = Document()
        document.id = documentID
        document.$project.id = project.id!
        document.$blob.id = blob.id!
        document.title = trimmedTitle
        try await document.save(on: db)

        return req.redirect(
            to: "/admin/projects/\(project.id!.uuidString)",
            redirectType: .normal
        )
    }

    // Download streams the file using the URL stashed on the parent
    // Blob row. Only local-store URLs are streamable today; everything
    // else returns 404 with a hint so the operator knows the row exists
    // but the bytes live elsewhere.
    app.get("admin", "documents", ":id", "download") { req -> Response in
        let document = try await loadDocument(req: req)
        let db = try await requireDatabaseService(req).db
        try await document.$blob.load(on: db)
        let url = document.blob.objectStorageUrl
        guard let path = req.application.documentStorage.localPath(for: url) else {
            throw Abort(
                .notFound,
                reason: "Document bytes live outside this deployment's local store."
            )
        }
        let response = try await req.fileio.asyncStreamFile(at: path)
        // Suggest the document's title as the filename to the browser so
        // the saved file is meaningful instead of the raw UUID on disk.
        response.headers.replaceOrAdd(
            name: .contentDisposition,
            value: #"attachment; filename="\#(document.title)""#
        )
        return response
    }

    // Delete removes the Document row and best-effort removes the file
    // bytes. The Blob row is removed too because Documents own their
    // backing Blob exclusively (polymorphic `referenced_by = documents`).
    app.on(.DELETE, "admin", "documents", ":id") { req -> Response in
        let document = try await loadDocument(req: req)
        let db = try await requireDatabaseService(req).db
        try await document.$blob.load(on: db)
        let projectID = document.$project.id
        let url = document.blob.objectStorageUrl
        try await document.delete(on: db)
        try await document.blob.delete(on: db)
        try? await req.application.documentStorage.remove(url: url)
        return req.redirect(
            to: "/admin/projects/\(projectID.uuidString)",
            redirectType: .normal
        )
    }
}

private struct DocumentUploadPayload: Content {
    var title: String?
    var file: File
}

private func loadDocument(req: Request) async throws -> Document {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid document id.")
    }
    let db = try await requireDatabaseService(req).db
    guard let document = try await Document.find(id, on: db) else {
        throw Abort(.notFound)
    }
    return document
}

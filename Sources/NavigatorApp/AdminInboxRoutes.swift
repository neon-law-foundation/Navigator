import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Routes for `/admin/inbox` — read-only inbound email view plus an
/// `acknowledge` action. Outbound `/admin/messages` is intentionally not
/// included yet because it requires relaxing the `EmailMessage` schema
/// (the SES verdict columns are not meaningful for sent mail) and that
/// migration is deferred.
func registerAdminInboxRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "inbox")

    group.get { req -> HTMLResponse in
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let messages = try await EmailMessage.query(on: db)
            .sort(\.$receivedAt, .descending)
            .all()
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            InboxIndexPage(brand: brand, messages: messages, flash: flash)
        }
    }

    group.get(":id") { req -> HTMLResponse in
        let message = try await loadInboxMessage(req: req)
        return HTMLResponse { InboxShowPage(brand: brand, message: message) }
    }

    group.post(":id", "acknowledge") { req -> Response in
        let message = try await loadInboxMessage(req: req)
        message.acknowledgedAt = Date()
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await message.save(on: db)
        let flash = encodeFlash("Message acknowledged.")
        return req.redirect(to: "/admin/inbox?flash=\(flash)", redirectType: .normal)
    }
}

private func loadInboxMessage(req: Request) async throws -> EmailMessage {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid message id.")
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    guard let message = try await EmailMessage.find(id, on: db) else {
        throw Abort(.notFound, reason: "Message not found.")
    }
    return message
}

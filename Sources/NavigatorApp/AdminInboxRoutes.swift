import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Routes for `/admin/inbox` — inbound mail view plus an acknowledge
/// action. Outbound rows live in the same `EmailMessage` table; this
/// surface filters them out via ``EmailMessage/direction`` so the inbox
/// stays focused on received mail.
func registerAdminInboxRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "inbox")

    group.get { req -> HTMLResponse in
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let all = try await EmailMessage.query(on: db)
            .sort(\.$receivedAt, .descending)
            .all()
        let inbound = all.filter { $0.direction == .inbound }
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            InboxIndexPage(brand: brand, messages: inbound, flash: flash)
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

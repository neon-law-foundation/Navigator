import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor

/// Bulk action endpoints — wrap the per-row affordances on index pages
/// so an operator catching up on a backlog can act on a batch in one
/// request instead of click-acknowledging one row at a time.
///
/// Each handler runs the batch inside a Fluent transaction so a
/// failure midway through leaves the database with the pre-batch
/// state intact.
func registerAdminBulkRoutes(_ app: Application, brand _: any Brand) {
    // Bulk acknowledge inbound mail. POST body shape is
    // `ids[]=<uuid>&ids[]=<uuid>` — matches the `name="ids[]"` checkbox
    // attribute the inbox table renders on each row.
    app.post("admin", "inbox", "acknowledge-bulk") { req -> Response in
        let payload = (try? req.content.decode(BulkIDsPayload.self)) ?? .empty
        let ids = payload.parsedIDs
        guard !ids.isEmpty else {
            return req.redirect(to: "/admin/inbox", redirectType: .normal)
        }
        let db = try await requireDatabaseService(req).db
        try await db.transaction { tx in
            let rows = try await EmailMessage.query(on: tx)
                .filter(\.$id ~~ ids)
                .all()
            for row in rows where row.acknowledgedAt == nil {
                row.acknowledgedAt = Date()
                try await row.save(on: tx)
            }
        }
        let flash = encodeFlash("Acknowledged \(ids.count) message\(ids.count == 1 ? "" : "s").")
        return req.redirect(to: "/admin/inbox?flash=\(flash)", redirectType: .normal)
    }

    // Bulk archive projects.
    app.post("admin", "projects", "archive-bulk") { req -> Response in
        let payload = (try? req.content.decode(BulkIDsPayload.self)) ?? .empty
        let ids = payload.parsedIDs
        guard !ids.isEmpty else {
            return req.redirect(to: "/admin/projects", redirectType: .normal)
        }
        let db = try await requireDatabaseService(req).db
        try await db.transaction { tx in
            let rows = try await Project.query(on: tx)
                .filter(\.$id ~~ ids)
                .all()
            for row in rows where row.status != .archived {
                row.status = .archived
                try await row.save(on: tx)
            }
        }
        let flash = encodeFlash("Archived \(ids.count) project\(ids.count == 1 ? "" : "s").")
        return req.redirect(to: "/admin/projects?flash=\(flash)", redirectType: .normal)
    }
}

/// Form payload for the bulk-action endpoints.
///
/// Vapor's URL-encoded decoder accepts both `ids=<uuid>` (single) and
/// `ids[]=<uuid>` (HTML's checkbox-with-name array convention). The
/// `ids` field on this struct holds the bracket-suffixed array; the
/// bare-key fallback (`ids` without brackets) lets the JSON form
/// `req.content.encode([:] as [String:String])` test case round-trip
/// to an empty selection.
private struct BulkIDsPayload: Content {
    var ids: [String]?

    static let empty = BulkIDsPayload(ids: nil)

    var parsedIDs: [UUID] {
        (ids ?? []).compactMap { UUID(uuidString: $0) }
    }
}

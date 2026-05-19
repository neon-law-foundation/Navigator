import Elementary
import FluentKit
import NavigatorDAL
import Vapor
import VaporElementary

/// `/admin/api/sidebar-badges/*` — small HTML fragments rendered into the
/// sidebar by HTMX.
///
/// The sidebar starts with empty placeholder slots; HTMX fires a `load`
/// trigger once after the document is parsed and then re-fetches every
/// 30 seconds, so an operator sitting on any admin page sees the unread
/// counter advance without a full navigation. The fragments return only
/// the inner content of the slot, so the route is cheap and stable —
/// callers don't need to know which slot they're populating.
///
/// `/inbox` returns the unread inbound-mail count. Zero unread renders
/// as an empty span so the sidebar stays uncluttered when the inbox is
/// drained.
func registerAdminSidebarBadgeRoutes(_ app: Application) {
    let group = app.grouped("admin", "api", "sidebar-badges")

    group.get("inbox") { req -> HTMLResponse in
        let count = try await loadUnreadInboxCount(req: req)
        return HTMLResponse { InboxBadgeFragment(count: count) }
    }
}

/// Counts every unread inbound `EmailMessage` row, regardless of which
/// support mailbox received it. The sidebar shows a single badge so the
/// count rolls up across all addresses this deployment listens on.
private func loadUnreadInboxCount(req: Request) async throws -> Int {
    guard let databaseService = req.application.databaseService else {
        return 0
    }
    let db = try await databaseService.db
    let unread = try await EmailMessage.query(on: db)
        .filter(\.$acknowledgedAt == nil)
        .all()
    return unread.filter { $0.direction == .inbound }.count
}

/// Inner-HTML payload for the `#inbox-badge` slot. Renders nothing when
/// the count is zero so the sidebar layout doesn't ghost an empty pill.
struct InboxBadgeFragment: HTML {
    let count: Int

    var body: some HTML {
        if count > 0 {
            span(
                .class(
                    "ml-2 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-rose-500 text-white"
                ),
                .custom(name: "data-badge", value: "inbox"),
                .custom(name: "data-count", value: String(count))
            ) { String(count) }
        } else {
            span(
                .custom(name: "data-badge", value: "inbox"),
                .custom(name: "data-count", value: "0")
            ) {}
        }
    }
}

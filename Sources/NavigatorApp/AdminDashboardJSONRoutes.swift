import FluentKit
import NavigatorDAL
import Vapor

/// `/admin/api/dashboard.json` — JSON snapshot of the resource counts
/// rendered on the admin dashboard.
///
/// Intended for monitoring scripts and ad-hoc curl checks. The shape
/// mirrors the dashboard tile view so an operator can `jq '.counts.inbox'`
/// without reading the HTML.
///
/// The response carries a stable contract — adding new keys is fine,
/// renaming or removing them is breaking. Counts that the dashboard can't
/// compute (no database available) surface as `null` so a consumer can
/// distinguish "no data yet" from a real zero.
func registerAdminDashboardJSONRoutes(_ app: Application) {
    app.get("admin", "api", "dashboard.json") { req -> Response in
        let counts = try await loadDashboardCounts(req: req)
        let payload = AdminDashboardJSONResponse(counts: counts)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(
            name: .contentType,
            value: "application/json; charset=utf-8"
        )
        return try await payload.encodeResponse(status: .ok, headers: headers, for: req)
    }
}

/// JSON payload for the dashboard snapshot. `Counts` keys are sorted
/// alphabetically by the encoder so a consumer diffing two snapshots
/// gets a stable shape across deployments.
struct AdminDashboardJSONResponse: Content {
    let counts: Counts

    struct Counts: Content {
        var billingProfiles: Int?
        var credentials: Int?
        var disclosures: Int?
        var entities: Int?
        var entityTypes: Int?
        var inbox: Int?
        var invoices: Int?
        var jurisdictions: Int?
        var mailrooms: Int?
        var messages: Int?
        var notations: Int?
        var people: Int?
        var projects: Int?
        var questions: Int?
        var retainers: Int?
        var shareClasses: Int?
        var shareIssuances: Int?
        var templates: Int?
        var userRoleAudit: Int?
        var users: Int?
    }
}

/// Loads the same counts the HTML dashboard uses. Pulled out so route
/// handlers can share the loader without binding to a particular view.
private func loadDashboardCounts(
    req: Request
) async throws -> AdminDashboardJSONResponse.Counts {
    guard let databaseService = req.application.databaseService else {
        return AdminDashboardJSONResponse.Counts()
    }
    let db = try await databaseService.db
    let messages = try? await EmailMessage.query(on: db).all()
    let inboundCount = messages.map { $0.filter { $0.direction == .inbound }.count }
    let outboundCount = messages.map { $0.filter { $0.direction == .outbound }.count }
    return AdminDashboardJSONResponse.Counts(
        billingProfiles: try? await EntityBillingProfile.query(on: db).count(),
        credentials: try? await Credential.query(on: db).count(),
        disclosures: try? await Disclosure.query(on: db).count(),
        entities: try? await Entity.query(on: db).count(),
        entityTypes: try? await EntityType.query(on: db).count(),
        inbox: inboundCount,
        invoices: try? await Invoice.query(on: db).count(),
        jurisdictions: try? await Jurisdiction.query(on: db).count(),
        mailrooms: try? await Mailroom.query(on: db).count(),
        messages: outboundCount,
        notations: try? await Notation.query(on: db).count(),
        people: try? await Person.query(on: db).count(),
        projects: try? await Project.query(on: db).count(),
        questions: try? await Question.query(on: db).count(),
        retainers: try? await Retainer.query(on: db).count(),
        shareClasses: try? await ShareClass.query(on: db).count(),
        shareIssuances: try? await ShareIssuance.query(on: db).count(),
        templates: try? await Template.query(on: db).count(),
        userRoleAudit: try? await UserRoleAudit.query(on: db).count(),
        users: try? await User.query(on: db).count()
    )
}

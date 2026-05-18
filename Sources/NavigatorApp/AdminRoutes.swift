import FluentKit
import NavigatorDAL
import NavigatorWeb
import Vapor
import VaporElementary

/// Registers every route under `/admin/*`.
///
/// Kept separate from ``routes(_:)`` so the admin surface — which is
/// large enough on its own to dominate the public route table — stays
/// grouped in one place. Routes here assume that ``configure(_:)`` has
/// already installed ``Application/useMethodOverride()`` so admin POSTs
/// carrying `_method=PATCH|DELETE` dispatch as the named verb.
public func registerAdminRoutes(_ app: Application, brand: any Brand) throws {
    app.get("admin") { req -> HTMLResponse in
        let tiles = try await dashboardTiles(req: req)
        return HTMLResponse { AdminDashboard(brand: brand, tiles: tiles) }
    }
    app.get("admin", "messages") { _ -> HTMLResponse in
        HTMLResponse { AdminMessagesPlaceholderPage(brand: brand) }
    }
}

/// Loads the per-resource counts the dashboard renders. Sections without
/// a counter yet (because the resource is not built or the count is
/// expensive) surface as `nil`, which the dashboard renders as a dash
/// instead of a misleading `0`.
private func dashboardTiles(req: Request) async throws -> [AdminDashboardTile] {
    let counts = try await loadResourceCounts(req: req)
    return AdminSection.allCases.map { section in
        AdminDashboardTile(section: section, count: counts[section] ?? nil)
    }
}

/// Resource counts the dashboard wants. Pulled in one place so a missing
/// database (test boot without wiring) renders an all-dashes dashboard
/// without per-section catch logic in the page.
private func loadResourceCounts(req: Request) async throws -> [AdminSection: Int?] {
    guard let databaseService = req.application.databaseService else {
        return [:]
    }
    let db = try await databaseService.db
    var counts: [AdminSection: Int?] = [:]
    counts[.projects] = try? await Project.query(on: db).count()
    counts[.people] = try? await Person.query(on: db).count()
    counts[.entities] = try? await Entity.query(on: db).count()
    counts[.entityTypes] = try? await EntityType.query(on: db).count()
    counts[.notations] = try? await Notation.query(on: db).count()
    counts[.templates] = try? await Template.query(on: db).count()
    counts[.questions] = try? await Question.query(on: db).count()
    counts[.retainers] = try? await Retainer.query(on: db).count()
    counts[.disclosures] = try? await Disclosure.query(on: db).count()
    counts[.credentials] = try? await Credential.query(on: db).count()
    counts[.invoices] = try? await Invoice.query(on: db).count()
    counts[.billingProfiles] = try? await EntityBillingProfile.query(on: db).count()
    counts[.jurisdictions] = try? await Jurisdiction.query(on: db).count()
    counts[.mailrooms] = try? await Mailroom.query(on: db).count()
    counts[.users] = try? await User.query(on: db).count()
    counts[.userRoleAudit] = try? await UserRoleAudit.query(on: db).count()
    counts[.shareClasses] = try? await ShareClass.query(on: db).count()
    counts[.shareIssuances] = try? await ShareIssuance.query(on: db).count()
    counts[.inbox] = try? await EmailMessage.query(on: db).count()
    counts[.messages] = try? await EmailMessage.query(on: db).count()
    return counts
}

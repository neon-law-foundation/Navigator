import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Single read-only route surface for the unified contacts landing.
/// `q` filters People by name/email and Entities by name with a
/// case-insensitive substring match. The page does its own deep-linking
/// to the per-resource detail pages.
func registerAdminContactsRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "contacts") { req -> HTMLResponse in
        let q = (try? req.query.get(String.self, at: "q")) ?? ""
        let rows = try await loadContacts(req: req, filter: q)
        return HTMLResponse {
            AdminContactsPage(brand: brand, contacts: rows, filter: q)
        }
    }
}

private func loadContacts(req: Request, filter: String) async throws -> [AdminContactRow] {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let allPeople = try await Person.query(on: db).sort(\.$name).all()
    let allEntities = try await Entity.query(on: db)
        .with(\.$legalEntityType)
        .sort(\.$name)
        .all()
    let matchedPeople: [Person]
    let matchedEntities: [Entity]
    if trimmed.isEmpty {
        matchedPeople = allPeople
        matchedEntities = allEntities
    } else {
        matchedPeople = allPeople.filter {
            $0.name.lowercased().contains(trimmed) || $0.email.lowercased().contains(trimmed)
        }
        matchedEntities = allEntities.filter {
            $0.name.lowercased().contains(trimmed)
        }
    }
    let personRows = matchedPeople.map(AdminContactRow.person)
    let entityRows = matchedEntities.map(AdminContactRow.entity)
    return (personRows + entityRows).sorted { $0.name.lowercased() < $1.name.lowercased() }
}

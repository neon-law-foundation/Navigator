import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// `/admin/search` routes — server-rendered global search with HTMX
/// fragment support.
///
/// When the request carries `HX-Request: true`, the route returns just
/// the results fragment (no chrome). A normal navigation receives the
/// full page. The URL alone is the source of truth in both modes, so
/// bookmarks and shared links work.
func registerAdminSearchRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "search") { req -> HTMLResponse in
        let query = (try? req.query.get(String.self, at: "q")) ?? ""
        let results = try await runSearch(req: req, query: query)
        let isHX = req.headers.first(name: "HX-Request") == "true"
        if isHX {
            return HTMLResponse {
                AdminSearchResults(query: query, results: results)
            }
        } else {
            return HTMLResponse {
                AdminSearchPage(brand: brand, query: query, results: results)
            }
        }
    }
}

/// Single-fetch substring search across the resources the operator is
/// most likely to look for. Per-resource matches max out at a small
/// limit so a broad query doesn't render a wall of rows.
private let searchSectionLimit = 10

private func runSearch(req: Request, query: String) async throws -> AdminSearchResultBundle {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else {
        return AdminSearchResultBundle(
            projects: [],
            people: [],
            entities: [],
            inbound: [],
            outbound: []
        )
    }
    let db = try await requireDatabaseService(req).db

    async let allProjects = Project.query(on: db).all()
    async let allPeople = Person.query(on: db).all()
    async let allEntities = Entity.query(on: db).with(\.$legalEntityType).all()
    async let allMessages = EmailMessage.query(on: db).all()

    let projects = try await allProjects.filter { p in
        p.codename.lowercased().contains(trimmed)
            || (p.title?.lowercased().contains(trimmed) ?? false)
    }
    let people = try await allPeople.filter {
        $0.name.lowercased().contains(trimmed) || $0.email.lowercased().contains(trimmed)
    }
    let entities = try await allEntities.filter { $0.name.lowercased().contains(trimmed) }
    let messages = try await allMessages.filter {
        $0.subject.lowercased().contains(trimmed)
            || $0.fromAddress.lowercased().contains(trimmed)
            || $0.toAddress.lowercased().contains(trimmed)
            || ($0.fromName?.lowercased().contains(trimmed) ?? false)
    }

    let inbound = messages.filter { $0.direction == .inbound }
    let outbound = messages.filter { $0.direction == .outbound }

    return AdminSearchResultBundle(
        projects: Array(projects.prefix(searchSectionLimit)),
        people: Array(people.prefix(searchSectionLimit)),
        entities: Array(entities.prefix(searchSectionLimit)),
        inbound: Array(inbound.prefix(searchSectionLimit)),
        outbound: Array(outbound.prefix(searchSectionLimit))
    )
}

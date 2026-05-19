import NavigatorDAL
import NavigatorWeb
import Vapor
import VaporElementary

/// Registers every public route served by the Neon Law Foundation site.
///
/// ### Route table
///
/// The HTML pages are listed here in declaration order so this file reads
/// like a Rails `routes.rb`. JSON API operations are generated from
/// `Sources/NavigatorWeb/openapi.yaml` and mounted at `/api/...` by
/// ``registerAPIRoutes(on:databaseService:serverURL:mailIngestSecret:)``.
///
/// | Method | Path                                       | View / handler            |
/// | ------ | ------------------------------------------ | ------------------------- |
/// | GET    | `/`                                        | `HomePage`                |
/// | GET    | `/about`                                   | `AboutPage`               |
/// | GET    | `/education`                               | `EducationPage`           |
/// | GET    | `/workshops`                               | 301 → `/workshops/genai-training` |
/// | GET    | `/workshops/genai-training`                | `WorkshopsPage`           |
/// | GET    | `/workshops/genai-training/:slug`          | `WorkshopMaterialPage`    |
/// | GET    | `/navigator`                               | `NavigatorPage`           |
/// | GET    | `/privacy`                                 | `PrivacyPage`             |
/// | GET    | `/terms`                                   | `TermsPage`               |
/// | GET    | `/contact`                                 | `ContactPage`             |
/// | GET    | `/blog`                                    | `BlogIndexPage`           |
/// | GET    | `/blog/:slug`                              | `BlogPostPage`            |
/// | GET    | `/admin/mailroom`                          | `MailroomPage` (all mail) |
/// | GET    | `/portal/mailroom`                         | `MailroomPage` (all mail) |
/// | GET    | `/health`                                  | DB round-trip probe       |
/// | GET    | `/openapi.yaml`                            | OpenAPI contract          |
/// | `*`    | `/api/...`                                 | OpenAPI-generated JSON    |
///
/// `/admin/mailroom` and `/portal/mailroom` render the same view today —
/// authentication is deferred, so the admin/portal split exists only as a
/// stable URL surface that auth middleware can later partition.
public func routes(_ app: Application) throws {
    let brand = NLFBrand()

    app.get { _ in
        HTMLResponse { HomePage(brand: brand) }
    }

    app.get("about") { _ in
        HTMLResponse { AboutPage(brand: brand) }
    }

    app.get("education") { _ in
        HTMLResponse { EducationPage(brand: brand) }
    }

    app.get("workshops", "genai-training") { req in
        HTMLResponse {
            WorkshopsPage(brand: brand, materials: req.application.workshopMaterials)
        }
    }

    app.get("workshops", "genai-training", ":slug") { req -> HTMLResponse in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.notFound)
        }
        guard let material = req.application.workshopMaterials.first(where: { $0.slug == slug })
        else {
            throw Abort(.notFound)
        }
        return HTMLResponse {
            WorkshopMaterialPage(brand: brand, material: material)
        }
    }

    // Preserve old bookmarks to the bare /workshops index by redirecting to
    // the canonical workshop landing page.
    app.get("workshops") { req -> Response in
        req.redirect(to: "/workshops/genai-training", redirectType: .permanent)
    }

    app.get("navigator") { _ in
        HTMLResponse { NavigatorPage(brand: brand) }
    }

    app.get("privacy") { _ in
        HTMLResponse { PrivacyPage(brand: brand) }
    }

    app.get("terms") { _ in
        HTMLResponse { TermsPage(brand: brand) }
    }

    app.get("contact") { _ in
        HTMLResponse { ContactPage(brand: brand) }
    }

    app.get("blog") { req in
        let posts = req.application.blogPosts
        return HTMLResponse { BlogIndexPage(brand: brand, posts: posts) }
    }

    app.get("blog", ":slug") { req -> HTMLResponse in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.notFound)
        }
        guard let post = req.application.blogPosts.first(where: { $0.slug == slug }) else {
            throw Abort(.notFound)
        }
        return HTMLResponse { BlogPostPage(brand: brand, post: post) }
    }

    try registerAdminRoutes(app, brand: brand)
    registerAdminSearchRoutes(app, brand: brand)
    registerAdminProjectsRoutes(app, brand: brand)
    registerAdminPeopleRoutes(app, brand: brand)
    registerAdminJurisdictionsRoutes(app, brand: brand)
    registerAdminEntityTypesRoutes(app, brand: brand)
    registerAdminEntitiesRoutes(app, brand: brand)
    registerAdminContactsRoutes(app, brand: brand)
    registerAdminWorkflowRoutes(app, brand: brand)
    registerAdminInboxRoutes(app, brand: brand)
    registerAdminMessagesRoutes(app, brand: brand)
    registerAdminRemainingRoutes(app, brand: brand)
    registerAdminLetterRoutes(app, brand: brand)
    registerAdminDocumentsRoutes(app, brand: brand)
    registerAdminCapTableRoutes(app, brand: brand)
    registerAdminBulkRoutes(app, brand: brand)

    app.get("admin", "mailroom") { req -> HTMLResponse in
        try await renderMailroom(req: req, brand: brand, portalLabel: "Admin", basePath: "/admin/mailroom")
    }

    app.get("portal", "mailroom") { req -> HTMLResponse in
        try await renderMailroom(req: req, brand: brand, portalLabel: "Portal", basePath: "/portal/mailroom")
    }

    // Readiness signal for orchestrators and load balancers. Returns 200
    // only when the database round-trips a query; failures surface as 503
    // so a rotating deployment can drain unhealthy tasks.
    app.get("health") { req -> Response in
        guard let databaseService = req.application.databaseService else {
            return Response(status: .serviceUnavailable, body: .init(string: "database unavailable"))
        }
        do {
            _ = try await databaseService.healthCheck()
            return Response(status: .ok, body: .init(string: "ok"))
        } catch {
            req.logger.error("database health check failed: \(error)")
            return Response(status: .serviceUnavailable, body: .init(string: "database unavailable"))
        }
    }

    // Publish the OpenAPI contract verbatim so external clients can
    // discover the JSON API surface without cloning this repository.
    // The spec ships as a bundled resource of `NavigatorWeb` and is
    // loaded once per request rather than cached — the file is small
    // and disk reads are negligible next to TLS termination.
    app.get("openapi.yaml") { _ -> Response in
        let yaml = try OpenAPISpec.yamlContents()
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: OpenAPISpec.contentType)
        return Response(status: .ok, headers: headers, body: .init(string: yaml))
    }
}

/// Renders one of the two mail-room URLs. The two routes only differ in
/// their `portalLabel` chip and the `basePath` they hand the column
/// headers so sort links stay on the same URL.
///
/// `?sort=` is parsed per JSON:API 1.1: comma-separated fields, leading
/// `-` for descending. Unknown fields are rejected with `400 Bad Request`
/// as the spec MUSTs. Absent `?sort=` falls back to ``MailroomPage/defaultSort``
/// so the active-sort arrow shows up on first load.
private func renderMailroom(
    req: Request,
    brand: any Brand,
    portalLabel: String,
    basePath: String
) async throws -> HTMLResponse {
    let raw = try? req.query.get(String.self, at: "sort")
    let parsed = SortSpec.parse(raw)
    let spec: SortSpec
    do {
        spec = try parsed.validated(against: MailroomPage.sortableKeys)
    } catch .unsupportedField(let key) {
        throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
    }
    let activeSpec = spec.fields.isEmpty ? MailroomPage.defaultSort : spec
    let letters = try await loadLetters(req: req)
    let sorted = MailroomPage.sorted(letters, by: activeSpec)
    return HTMLResponse {
        MailroomPage(
            brand: brand,
            portalLabel: portalLabel,
            basePath: basePath,
            letters: sorted,
            sort: activeSpec
        )
    }
}

/// Fetches every `Letter` row with its mailroom eager-loaded so the mail
/// room view can render without per-row queries. Returns an empty array
/// when the database has not been wired up — the page renders its empty
/// state in that case rather than 503-ing the request.
private func loadLetters(req: Request) async throws -> [Letter] {
    guard let databaseService = req.application.databaseService else {
        return []
    }
    let db = try await databaseService.db
    return try await LetterRepository(database: db).findAllWithMailroom()
}

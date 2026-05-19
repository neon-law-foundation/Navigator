import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

func registerAdminJurisdictionsRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "jurisdictions")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: JurisdictionsIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? JurisdictionsIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let rows = try await Jurisdiction.query(on: db).all()
        let processed = JurisdictionsIndexPage.sorted(
            JurisdictionsIndexPage.filtered(rows, by: filter),
            by: activeSpec
        )
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            JurisdictionsIndexPage(
                brand: brand,
                jurisdictions: processed,
                flash: flash,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get("new") { _ -> HTMLResponse in
        HTMLResponse {
            JurisdictionFormPage(
                brand: brand,
                mode: .new,
                form: JurisdictionFormValues(),
                errors: .none
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(JurisdictionPayload.self)) ?? .empty
        let values = payload.values
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let errors = validate(values: values)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                JurisdictionFormPage(brand: brand, mode: .new, form: values, errors: errors)
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let j = Jurisdiction()
        apply(values: values, to: j)
        try await j.save(on: db)
        let flash = encodeFlash("Jurisdiction \(j.name) created.")
        return req.redirect(to: "/admin/jurisdictions?flash=\(flash)", redirectType: .normal)
    }

    group.get(":id") { req -> HTMLResponse in
        let j = try await loadJurisdiction(req: req)
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let types = try await EntityType.query(on: db)
            .filter(\.$jurisdiction.$id == j.id!)
            .sort(\.$name)
            .all()
        return HTMLResponse {
            JurisdictionShowPage(brand: brand, jurisdiction: j, entityTypes: types)
        }
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let j = try await loadJurisdiction(req: req)
        return HTMLResponse {
            JurisdictionFormPage(
                brand: brand,
                mode: .edit(id: j.id?.uuidString ?? ""),
                form: JurisdictionFormValues(jurisdiction: j),
                errors: .none
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let j = try await loadJurisdiction(req: req)
        let payload = (try? req.content.decode(JurisdictionPayload.self)) ?? .empty
        let values = payload.values
        let errors = validate(values: values)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                JurisdictionFormPage(
                    brand: brand,
                    mode: .edit(id: j.id?.uuidString ?? ""),
                    form: values,
                    errors: errors
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        apply(values: values, to: j)
        try await j.save(on: db)
        let flash = encodeFlash("Jurisdiction \(j.name) updated.")
        return req.redirect(to: "/admin/jurisdictions?flash=\(flash)", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let j = try await loadJurisdiction(req: req)
        let name = j.name
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await JurisdictionRepository(database: db).delete(id: j.id!)
        let flash = encodeFlash("Jurisdiction \(name) deleted.")
        return req.redirect(to: "/admin/jurisdictions?flash=\(flash)", redirectType: .normal)
    }
}

private struct JurisdictionPayload: Content {
    var name: String?
    var code: String?
    var jurisdictionType: String?

    static let empty = JurisdictionPayload(name: nil, code: nil, jurisdictionType: nil)

    var values: JurisdictionFormValues {
        JurisdictionFormValues(
            name: name ?? "",
            code: code ?? "",
            jurisdictionType: jurisdictionType ?? ""
        )
    }
}

private func validate(values: JurisdictionFormValues) -> JurisdictionFormErrors {
    var summary: [String] = []
    let trimmedName = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedCode = values.code.trimmingCharacters(in: .whitespacesAndNewlines)
    let nameError: String? = trimmedName.isEmpty ? "Name is required." : nil
    let codeError: String? = trimmedCode.isEmpty ? "Code is required." : nil
    let typeError: String? =
        values.typeEnum == nil ? "Pick a jurisdiction type." : nil
    if let nameError { summary.append(nameError) }
    if let codeError { summary.append(codeError) }
    if let typeError { summary.append(typeError) }
    return JurisdictionFormErrors(
        name: nameError,
        code: codeError,
        jurisdictionType: typeError,
        summary: summary
    )
}

private func apply(values: JurisdictionFormValues, to j: Jurisdiction) {
    j.name = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    j.code = values.code.trimmingCharacters(in: .whitespacesAndNewlines)
    if let type = values.typeEnum {
        j.jurisdictionType = type
    }
}

private func loadJurisdiction(req: Request) async throws -> Jurisdiction {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid jurisdiction id.")
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    guard let j = try await JurisdictionRepository(database: db).find(id: id) else {
        throw Abort(.notFound, reason: "Jurisdiction not found.")
    }
    return j
}

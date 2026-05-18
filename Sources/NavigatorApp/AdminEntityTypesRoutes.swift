import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

func registerAdminEntityTypesRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "entity-types")

    group.get { req -> HTMLResponse in
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let types = try await EntityType.query(on: db)
            .with(\.$jurisdiction)
            .sort(\.$name)
            .all()
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            EntityTypesIndexPage(brand: brand, entityTypes: types, flash: flash)
        }
    }

    group.get("new") { req -> HTMLResponse in
        let jurisdictions = try await loadJurisdictionsSorted(req: req)
        return HTMLResponse {
            EntityTypeFormPage(
                brand: brand,
                mode: .new,
                form: EntityTypeFormValues(),
                errors: .none,
                jurisdictions: jurisdictions
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(EntityTypePayload.self)) ?? .empty
        let values = payload.values
        let jurisdictions = try await loadJurisdictionsSorted(req: req)
        let errors = validate(values: values, jurisdictions: jurisdictions)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                EntityTypeFormPage(
                    brand: brand,
                    mode: .new,
                    form: values,
                    errors: errors,
                    jurisdictions: jurisdictions
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let type = EntityType()
        apply(values: values, to: type)
        try await type.save(on: db)
        let flash = encodeFlash("Entity type \(type.name) created.")
        return req.redirect(to: "/admin/entity-types?flash=\(flash)", redirectType: .normal)
    }

    group.get(":id") { req -> HTMLResponse in
        let type = try await loadEntityType(req: req)
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let entities = try await Entity.query(on: db)
            .filter(\.$legalEntityType.$id == type.id!)
            .sort(\.$name)
            .all()
        return HTMLResponse {
            EntityTypeShowPage(brand: brand, entityType: type, entities: entities)
        }
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let type = try await loadEntityType(req: req)
        let jurisdictions = try await loadJurisdictionsSorted(req: req)
        return HTMLResponse {
            EntityTypeFormPage(
                brand: brand,
                mode: .edit(id: type.id?.uuidString ?? ""),
                form: EntityTypeFormValues(entityType: type),
                errors: .none,
                jurisdictions: jurisdictions
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let type = try await loadEntityType(req: req)
        let payload = (try? req.content.decode(EntityTypePayload.self)) ?? .empty
        let values = payload.values
        let jurisdictions = try await loadJurisdictionsSorted(req: req)
        let errors = validate(values: values, jurisdictions: jurisdictions)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                EntityTypeFormPage(
                    brand: brand,
                    mode: .edit(id: type.id?.uuidString ?? ""),
                    form: values,
                    errors: errors,
                    jurisdictions: jurisdictions
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        apply(values: values, to: type)
        try await type.save(on: db)
        let flash = encodeFlash("Entity type \(type.name) updated.")
        return req.redirect(to: "/admin/entity-types?flash=\(flash)", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let type = try await loadEntityType(req: req)
        let name = type.name
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await EntityTypeRepository(database: db).delete(id: type.id!)
        let flash = encodeFlash("Entity type \(name) deleted.")
        return req.redirect(to: "/admin/entity-types?flash=\(flash)", redirectType: .normal)
    }
}

private struct EntityTypePayload: Content {
    var name: String?
    var jurisdictionId: String?

    static let empty = EntityTypePayload(name: nil, jurisdictionId: nil)

    var values: EntityTypeFormValues {
        EntityTypeFormValues(name: name ?? "", jurisdictionId: jurisdictionId ?? "")
    }
}

private func validate(
    values: EntityTypeFormValues,
    jurisdictions: [Jurisdiction]
) -> EntityTypeFormErrors {
    var summary: [String] = []
    let nameTrim = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let nameError: String? = nameTrim.isEmpty ? "Name is required." : nil
    let jurisdictionError: String?
    if values.jurisdictionId.isEmpty {
        jurisdictionError = "Pick a jurisdiction."
    } else if UUID(uuidString: values.jurisdictionId) == nil
        || !jurisdictions.contains(where: { $0.id?.uuidString == values.jurisdictionId })
    {
        jurisdictionError = "Pick a valid jurisdiction."
    } else {
        jurisdictionError = nil
    }
    if let nameError { summary.append(nameError) }
    if let jurisdictionError { summary.append(jurisdictionError) }
    return EntityTypeFormErrors(
        name: nameError,
        jurisdictionId: jurisdictionError,
        summary: summary
    )
}

private func apply(values: EntityTypeFormValues, to type: EntityType) {
    type.name = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let id = UUID(uuidString: values.jurisdictionId) {
        type.$jurisdiction.id = id
    }
}

private func loadEntityType(req: Request) async throws -> EntityType {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid entity type id.")
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    guard
        let type = try await EntityType.query(on: db)
            .with(\.$jurisdiction)
            .filter(\.$id == id)
            .first()
    else {
        throw Abort(.notFound, reason: "Entity type not found.")
    }
    return type
}

func loadJurisdictionsSorted(req: Request) async throws -> [Jurisdiction] {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    return try await Jurisdiction.query(on: db).sort(\.$name).all()
}

import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

func registerAdminEntitiesRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "entities")

    group.get { req -> HTMLResponse in
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let entities = try await Entity.query(on: db)
            .with(\.$legalEntityType)
            .sort(\.$name)
            .all()
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            EntitiesIndexPage(brand: brand, entities: entities, flash: flash)
        }
    }

    group.get("new") { req -> HTMLResponse in
        let types = try await loadEntityTypesSorted(req: req)
        return HTMLResponse {
            EntityFormPage(
                brand: brand,
                mode: .new,
                form: EntityFormValues(),
                errors: .none,
                entityTypes: types
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(EntityPayload.self)) ?? .empty
        let values = payload.values
        let types = try await loadEntityTypesSorted(req: req)
        let errors = validate(values: values, entityTypes: types)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                EntityFormPage(
                    brand: brand,
                    mode: .new,
                    form: values,
                    errors: errors,
                    entityTypes: types
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let entity = Entity()
        apply(values: values, to: entity)
        try await entity.save(on: db)
        let flash = encodeFlash("Entity \(entity.name) created.")
        return req.redirect(to: "/admin/entities?flash=\(flash)", redirectType: .normal)
    }

    group.get(":id") { req -> HTMLResponse in
        let entity = try await loadEntity(req: req)
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let people = try await PersonEntityRole.query(on: db)
            .filter(\.$entity.$id == entity.id!)
            .with(\.$person)
            .all()
        return HTMLResponse {
            EntityShowPage(brand: brand, entity: entity, people: people)
        }
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let entity = try await loadEntity(req: req)
        let types = try await loadEntityTypesSorted(req: req)
        return HTMLResponse {
            EntityFormPage(
                brand: brand,
                mode: .edit(id: entity.id?.uuidString ?? ""),
                form: EntityFormValues(entity: entity),
                errors: .none,
                entityTypes: types
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let entity = try await loadEntity(req: req)
        let payload = (try? req.content.decode(EntityPayload.self)) ?? .empty
        let values = payload.values
        let types = try await loadEntityTypesSorted(req: req)
        let errors = validate(values: values, entityTypes: types)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                EntityFormPage(
                    brand: brand,
                    mode: .edit(id: entity.id?.uuidString ?? ""),
                    form: values,
                    errors: errors,
                    entityTypes: types
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        apply(values: values, to: entity)
        try await entity.save(on: db)
        let flash = encodeFlash("Entity \(entity.name) updated.")
        return req.redirect(to: "/admin/entities?flash=\(flash)", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let entity = try await loadEntity(req: req)
        let name = entity.name
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await EntityRepository(database: db).delete(id: entity.id!)
        let flash = encodeFlash("Entity \(name) deleted.")
        return req.redirect(to: "/admin/entities?flash=\(flash)", redirectType: .normal)
    }
}

private struct EntityPayload: Content {
    var name: String?
    var legalEntityTypeId: String?

    static let empty = EntityPayload(name: nil, legalEntityTypeId: nil)

    var values: EntityFormValues {
        EntityFormValues(name: name ?? "", legalEntityTypeId: legalEntityTypeId ?? "")
    }
}

private func validate(
    values: EntityFormValues,
    entityTypes: [EntityType]
) -> EntityFormErrors {
    var summary: [String] = []
    let nameTrim = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let nameError: String? = nameTrim.isEmpty ? "Name is required." : nil
    let typeError: String?
    if values.legalEntityTypeId.isEmpty {
        typeError = "Pick an entity type."
    } else if UUID(uuidString: values.legalEntityTypeId) == nil
        || !entityTypes.contains(where: { $0.id?.uuidString == values.legalEntityTypeId })
    {
        typeError = "Pick a valid entity type."
    } else {
        typeError = nil
    }
    if let nameError { summary.append(nameError) }
    if let typeError { summary.append(typeError) }
    return EntityFormErrors(
        name: nameError,
        legalEntityTypeId: typeError,
        summary: summary
    )
}

private func apply(values: EntityFormValues, to entity: Entity) {
    entity.name = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let id = UUID(uuidString: values.legalEntityTypeId) {
        entity.$legalEntityType.id = id
    }
}

private func loadEntity(req: Request) async throws -> Entity {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid entity id.")
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    guard
        let entity = try await Entity.query(on: db)
            .with(\.$legalEntityType)
            .filter(\.$id == id)
            .first()
    else {
        throw Abort(.notFound, reason: "Entity not found.")
    }
    return entity
}

func loadEntityTypesSorted(req: Request) async throws -> [EntityType] {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    return try await EntityType.query(on: db)
        .with(\.$jurisdiction)
        .sort(\.$name)
        .all()
}

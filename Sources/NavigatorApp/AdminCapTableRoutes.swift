import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// CRUD routes for the cap-table resources.
///
/// The read-only index/show routes live in `AdminRemainingRoutes`; this
/// file adds the authoring paths (`new`, `create`, `edit`, `update`,
/// `destroy`) on top of them. Issuance posts validate the polymorphic
/// shareholder pointer before saving so a person-typed row cannot point
/// at an entity id, and vice versa.
func registerAdminCapTableRoutes(_ app: Application, brand: any Brand) {
    registerShareClassCRUD(app, brand: brand)
    registerShareIssuanceCRUD(app, brand: brand)
}

// MARK: - ShareClass

private func registerShareClassCRUD(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "share-classes")

    group.get("new") { req -> HTMLResponse in
        let entities = try await loadEntities(req: req)
        return HTMLResponse {
            ShareClassFormPage(
                brand: brand,
                mode: .new,
                form: ShareClassFormValues(),
                errors: .none,
                entities: entities
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(ShareClassPayload.self)) ?? .empty
        let values = payload.values
        let entities = try await loadEntities(req: req)
        let db = try await requireDatabaseService(req).db
        let errors = await validateShareClass(
            values: values,
            entities: entities,
            db: db,
            existingID: nil
        )
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                ShareClassFormPage(
                    brand: brand,
                    mode: .new,
                    form: values,
                    errors: errors,
                    entities: entities
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let sc = ShareClass()
        applyShareClass(values: values, to: sc)
        try await sc.save(on: db)
        return req.redirect(to: "/admin/share-classes", redirectType: .normal)
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let sc = try await loadShareClass(req: req)
        let entities = try await loadEntities(req: req)
        return HTMLResponse {
            ShareClassFormPage(
                brand: brand,
                mode: .edit(id: sc.id?.uuidString ?? ""),
                form: ShareClassFormValues(shareClass: sc),
                errors: .none,
                entities: entities
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let sc = try await loadShareClass(req: req)
        let payload = (try? req.content.decode(ShareClassPayload.self)) ?? .empty
        let values = payload.values
        let entities = try await loadEntities(req: req)
        let db = try await requireDatabaseService(req).db
        let errors = await validateShareClass(
            values: values,
            entities: entities,
            db: db,
            existingID: sc.id
        )
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                ShareClassFormPage(
                    brand: brand,
                    mode: .edit(id: sc.id?.uuidString ?? ""),
                    form: values,
                    errors: errors,
                    entities: entities
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        applyShareClass(values: values, to: sc)
        try await sc.save(on: db)
        return req.redirect(to: "/admin/share-classes", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let sc = try await loadShareClass(req: req)
        let db = try await requireDatabaseService(req).db
        try await sc.delete(on: db)
        return req.redirect(to: "/admin/share-classes", redirectType: .normal)
    }
}

private struct ShareClassPayload: Content {
    var name: String?
    var entityId: String?
    var priority: String?
    var description: String?

    static let empty = ShareClassPayload(
        name: nil,
        entityId: nil,
        priority: nil,
        description: nil
    )

    var values: ShareClassFormValues {
        ShareClassFormValues(
            name: name ?? "",
            entityId: entityId ?? "",
            priority: priority ?? "",
            description: description ?? ""
        )
    }
}

private func validateShareClass(
    values: ShareClassFormValues,
    entities: [Entity],
    db: Database,
    existingID: UUID?
) async -> ShareClassFormErrors {
    var summary: [String] = []
    let nameTrim = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    var nameError: String? = nil
    if nameTrim.isEmpty {
        nameError = "Name is required."
        summary.append(nameError!)
    }
    var entityError: String? = nil
    let entityID = UUID(uuidString: values.entityId)
    if entityID == nil || !entities.contains(where: { $0.id == entityID }) {
        entityError = "Pick a valid entity."
        summary.append(entityError!)
    }
    var priorityError: String? = nil
    guard let priority = Int(values.priority) else {
        priorityError = "Priority must be an integer."
        summary.append(priorityError!)
        return ShareClassFormErrors(
            name: nameError,
            entityId: entityError,
            priority: priorityError,
            description: nil,
            summary: summary
        )
    }
    if let entityID, entityError == nil {
        if let existing = try? await ShareClass.query(on: db)
            .filter(\.$entity.$id == entityID)
            .filter(\.$priority == priority)
            .first(),
            existing.id != existingID
        {
            priorityError = "Priority is already used on this entity."
            summary.append(priorityError!)
        }
    }
    return ShareClassFormErrors(
        name: nameError,
        entityId: entityError,
        priority: priorityError,
        description: nil,
        summary: summary
    )
}

private func applyShareClass(values: ShareClassFormValues, to sc: ShareClass) {
    sc.name = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let id = UUID(uuidString: values.entityId) { sc.$entity.id = id }
    if let priority = Int(values.priority) { sc.priority = priority }
    let trimmedDesc = values.description.trimmingCharacters(in: .whitespacesAndNewlines)
    sc.description = trimmedDesc.isEmpty ? nil : trimmedDesc
}

private func loadShareClass(req: Request) async throws -> ShareClass {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid share class id.")
    }
    let db = try await requireDatabaseService(req).db
    guard let sc = try await ShareClass.find(id, on: db) else {
        throw Abort(.notFound)
    }
    return sc
}

private func loadEntities(req: Request) async throws -> [Entity] {
    let db = try await requireDatabaseService(req).db
    return try await Entity.query(on: db).sort(\.$name).all()
}

// MARK: - ShareIssuance

private func registerShareIssuanceCRUD(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "share-issuances")

    group.get("new") { req -> HTMLResponse in
        let (entities, people) = try await loadIssuanceDeps(req: req)
        return HTMLResponse {
            ShareIssuanceFormPage(
                brand: brand,
                mode: .new,
                form: ShareIssuanceFormValues(),
                errors: .none,
                entities: entities,
                people: people
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(ShareIssuancePayload.self)) ?? .empty
        let values = payload.values
        let (entities, people) = try await loadIssuanceDeps(req: req)
        let errors = validateShareIssuance(values: values, entities: entities, people: people)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                ShareIssuanceFormPage(
                    brand: brand,
                    mode: .new,
                    form: values,
                    errors: errors,
                    entities: entities,
                    people: people
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        let issuance = ShareIssuance()
        applyShareIssuance(values: values, to: issuance)
        try await issuance.save(on: db)
        return req.redirect(to: "/admin/share-issuances", redirectType: .normal)
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let issuance = try await loadShareIssuance(req: req)
        let (entities, people) = try await loadIssuanceDeps(req: req)
        return HTMLResponse {
            ShareIssuanceFormPage(
                brand: brand,
                mode: .edit(id: issuance.id?.uuidString ?? ""),
                form: ShareIssuanceFormValues(issuance: issuance),
                errors: .none,
                entities: entities,
                people: people
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let issuance = try await loadShareIssuance(req: req)
        let payload = (try? req.content.decode(ShareIssuancePayload.self)) ?? .empty
        let values = payload.values
        let (entities, people) = try await loadIssuanceDeps(req: req)
        let errors = validateShareIssuance(values: values, entities: entities, people: people)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                ShareIssuanceFormPage(
                    brand: brand,
                    mode: .edit(id: issuance.id?.uuidString ?? ""),
                    form: values,
                    errors: errors,
                    entities: entities,
                    people: people
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        applyShareIssuance(values: values, to: issuance)
        try await issuance.save(on: db)
        return req.redirect(to: "/admin/share-issuances", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let issuance = try await loadShareIssuance(req: req)
        let db = try await requireDatabaseService(req).db
        try await issuance.delete(on: db)
        return req.redirect(to: "/admin/share-issuances", redirectType: .normal)
    }
}

private struct ShareIssuancePayload: Content {
    var entityId: String?
    var shareholderType: String?
    var personShareholderId: String?
    var entityShareholderId: String?

    static let empty = ShareIssuancePayload(
        entityId: nil,
        shareholderType: nil,
        personShareholderId: nil,
        entityShareholderId: nil
    )

    var values: ShareIssuanceFormValues {
        ShareIssuanceFormValues(
            entityId: entityId ?? "",
            shareholderType: shareholderType ?? "person",
            personShareholderId: personShareholderId ?? "",
            entityShareholderId: entityShareholderId ?? ""
        )
    }
}

private func validateShareIssuance(
    values: ShareIssuanceFormValues,
    entities: [Entity],
    people: [Person]
) -> ShareIssuanceFormErrors {
    var summary: [String] = []
    var entityError: String? = nil
    let entityID = UUID(uuidString: values.entityId)
    if entityID == nil || !entities.contains(where: { $0.id == entityID }) {
        entityError = "Pick a valid issuing entity."
        summary.append(entityError!)
    }
    var typeError: String? = nil
    guard let kind = values.shareholderTypeEnum else {
        typeError = "Pick a shareholder type."
        summary.append(typeError!)
        return ShareIssuanceFormErrors(
            entityId: entityError,
            shareholderType: typeError,
            personShareholderId: nil,
            entityShareholderId: nil,
            summary: summary
        )
    }
    var personError: String? = nil
    var entityShareError: String? = nil
    switch kind {
    case .person:
        let id = UUID(uuidString: values.personShareholderId)
        if id == nil || !people.contains(where: { $0.id == id }) {
            personError = "Pick a person shareholder."
            summary.append(personError!)
        }
    case .entity:
        let id = UUID(uuidString: values.entityShareholderId)
        if id == nil || !entities.contains(where: { $0.id == id }) {
            entityShareError = "Pick an entity shareholder."
            summary.append(entityShareError!)
        }
    }
    return ShareIssuanceFormErrors(
        entityId: entityError,
        shareholderType: typeError,
        personShareholderId: personError,
        entityShareholderId: entityShareError,
        summary: summary
    )
}

private func applyShareIssuance(values: ShareIssuanceFormValues, to issuance: ShareIssuance) {
    if let id = UUID(uuidString: values.entityId) { issuance.$entity.id = id }
    if let kind = values.shareholderTypeEnum {
        issuance.shareholderType = kind
        switch kind {
        case .person:
            if let id = UUID(uuidString: values.personShareholderId) {
                issuance.shareholderId = id
            }
        case .entity:
            if let id = UUID(uuidString: values.entityShareholderId) {
                issuance.shareholderId = id
            }
        }
    }
}

private func loadShareIssuance(req: Request) async throws -> ShareIssuance {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest)
    }
    let db = try await requireDatabaseService(req).db
    guard let issuance = try await ShareIssuance.find(id, on: db) else {
        throw Abort(.notFound)
    }
    return issuance
}

private func loadIssuanceDeps(req: Request) async throws -> ([Entity], [Person]) {
    let db = try await requireDatabaseService(req).db
    async let entities = Entity.query(on: db).sort(\.$name).all()
    async let people = Person.query(on: db).sort(\.$name).all()
    return try await (entities, people)
}

import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Registers the `/admin/people/*` resource routes.
///
/// Mirrors the shape of ``registerAdminProjectsRoutes(_:brand:)``.
func registerAdminPeopleRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "people")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: PeopleIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? PeopleIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let all = try await loadPeople(req: req)
        let sorted = PeopleIndexPage.sorted(
            PeopleIndexPage.filtered(all, by: filter),
            by: activeSpec
        )
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            PeopleIndexPage(
                brand: brand,
                people: sorted,
                flash: flash,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get("new") { _ -> HTMLResponse in
        HTMLResponse {
            PersonFormPage(brand: brand, mode: .new, form: PersonFormValues(), errors: .none)
        }
    }

    group.post { req -> Response in
        let submitted = (try? req.content.decode(PersonFormPayload.self)) ?? .empty
        let values = submitted.values
        let result = try await createPerson(req: req, values: values)
        switch result {
        case .success(let person):
            let flash = encodeFlash("Person \(person.name) created.")
            return req.redirect(to: "/admin/people?flash=\(flash)", redirectType: .normal)
        case .failure(let errors):
            let html = HTMLResponse {
                PersonFormPage(brand: brand, mode: .new, form: values, errors: errors)
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
    }

    group.get(":id") { req -> HTMLResponse in
        let person = try await loadPerson(req: req)
        let (assignments, entityRoles) = try await loadPersonAssociations(
            req: req,
            person: person
        )
        return HTMLResponse {
            PersonShowPage(
                brand: brand,
                person: person,
                projectAssignments: assignments,
                entityRoles: entityRoles
            )
        }
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let person = try await loadPerson(req: req)
        return HTMLResponse {
            PersonFormPage(
                brand: brand,
                mode: .edit(id: person.id?.uuidString ?? ""),
                form: PersonFormValues(person: person),
                errors: .none
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let person = try await loadPerson(req: req)
        let submitted = (try? req.content.decode(PersonFormPayload.self)) ?? .empty
        let values = submitted.values
        let result = try await updatePerson(req: req, person: person, values: values)
        switch result {
        case .success(let updated):
            let flash = encodeFlash("Person \(updated.name) updated.")
            return req.redirect(to: "/admin/people?flash=\(flash)", redirectType: .normal)
        case .failure(let errors):
            let html = HTMLResponse {
                PersonFormPage(
                    brand: brand,
                    mode: .edit(id: person.id?.uuidString ?? ""),
                    form: values,
                    errors: errors
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
    }

    group.on(.DELETE, ":id") { req -> Response in
        let person = try await loadPerson(req: req)
        let name = person.name
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await PersonRepository(database: db).delete(id: person.id!)
        let flash = encodeFlash("Person \(name) deleted.")
        return req.redirect(to: "/admin/people?flash=\(flash)", redirectType: .normal)
    }
}

private struct PersonFormPayload: Content {
    var name: String?
    var email: String?

    static let empty = PersonFormPayload(name: nil, email: nil)

    var values: PersonFormValues {
        PersonFormValues(name: name ?? "", email: email ?? "")
    }
}

private enum PersonMutationResult {
    case success(Person)
    case failure(PersonFormErrors)
}

private func createPerson(
    req: Request,
    values: PersonFormValues
) async throws -> PersonMutationResult {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    let repo = PersonRepository(database: db)
    let errors = await validatePerson(values: values, repo: repo, existingID: nil)
    if !errors.summary.isEmpty {
        return .failure(errors)
    }
    let person = Person()
    applyPerson(values: values, to: person)
    _ = try await repo.create(model: person)
    return .success(person)
}

private func updatePerson(
    req: Request,
    person: Person,
    values: PersonFormValues
) async throws -> PersonMutationResult {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    let repo = PersonRepository(database: db)
    let errors = await validatePerson(values: values, repo: repo, existingID: person.id)
    if !errors.summary.isEmpty {
        return .failure(errors)
    }
    applyPerson(values: values, to: person)
    _ = try await repo.update(model: person)
    return .success(person)
}

private func validatePerson(
    values: PersonFormValues,
    repo: PersonRepository,
    existingID: UUID?
) async -> PersonFormErrors {
    var summary: [String] = []
    var nameError: String? = nil
    var emailError: String? = nil

    let trimmedName = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedName.isEmpty {
        nameError = "Name is required."
        summary.append("Name is required.")
    }

    let trimmedEmail = values.email.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedEmail.isEmpty {
        emailError = "Email is required."
        summary.append("Email is required.")
    } else if !trimmedEmail.contains("@") {
        emailError = "Email must look like an email address."
        summary.append("Email must look like an email address.")
    } else if let existing = try? await repo.findByEmail(trimmedEmail),
        existing.id != existingID
    {
        emailError = "Email is already in use."
        summary.append("Email is already in use.")
    }

    return PersonFormErrors(name: nameError, email: emailError, summary: summary)
}

private func applyPerson(values: PersonFormValues, to person: Person) {
    person.name = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    person.email = values.email.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func loadPeople(req: Request) async throws -> [Person] {
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    return try await Person.query(on: db).sort(\.$name, .ascending).all()
}

private func loadPerson(req: Request) async throws -> Person {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid person id.")
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    guard let person = try await PersonRepository(database: db).find(id: id) else {
        throw Abort(.notFound, reason: "Person not found.")
    }
    return person
}

private func loadPersonAssociations(
    req: Request,
    person: Person
) async throws -> ([PersonProjectRole], [PersonEntityRole]) {
    guard let personID = person.id else { return ([], []) }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    async let projects = PersonProjectRole.query(on: db)
        .filter(\.$person.$id == personID)
        .with(\.$project)
        .all()
    async let entities = PersonEntityRole.query(on: db)
        .filter(\.$person.$id == personID)
        .with(\.$entity)
        .all()
    return try await (projects, entities)
}

import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Wires every remaining admin section so no sidebar link 404s.
///
/// Read-only resources (Retainers, Invoices, Users, UserRoleAudit, Share
/// classes, Share issuances) ship index + show pages. Small lookup
/// resources (Credentials, Mailrooms) ship full CRUD. Disclosures and
/// Billing profiles are read-only because both are produced by other
/// systems (the access model and the Xero sync respectively).
func registerAdminRemainingRoutes(_ app: Application, brand: any Brand) {
    registerRetainerRoutes(app, brand: brand)
    registerDisclosureRoutes(app, brand: brand)
    registerCredentialRoutes(app, brand: brand)
    registerInvoiceRoutes(app, brand: brand)
    registerBillingProfileRoutes(app, brand: brand)
    registerMailroomRoutes(app, brand: brand)
    registerUserRoutes(app, brand: brand)
    registerShareEquityRoutes(app, brand: brand)
}

// MARK: - Retainers

private func registerRetainerRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "retainers")
    group.get { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await Retainer.query(on: db).sort(\.$status).all()
        return HTMLResponse { RetainersIndexPage(brand: brand, retainers: rows) }
    }
    group.get(":id") { req -> HTMLResponse in
        guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
            throw Abort(.badRequest, reason: "Invalid retainer id.")
        }
        let db = try await requireDatabaseService(req).db
        guard let r = try await Retainer.find(id, on: db) else {
            throw Abort(.notFound)
        }
        let activity = try await loadRetainerActivity(retainer: r, db: db)
        return HTMLResponse {
            RetainerShowPage(brand: brand, retainer: r, activity: activity)
        }
    }
}

// MARK: - Disclosures

private func registerDisclosureRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "disclosures") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await Disclosure.query(on: db)
            .with(\.$credential) { $0.with(\.$person) }
            .with(\.$project)
            .sort(\.$disclosedAt, .descending)
            .all()
        return HTMLResponse { DisclosuresIndexPage(brand: brand, disclosures: rows) }
    }
}

// MARK: - Credentials (full CRUD)

private func registerCredentialRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "credentials")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: CredentialsIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? CredentialsIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let db = try await requireDatabaseService(req).db
        let rows = try await Credential.query(on: db)
            .with(\.$person)
            .with(\.$jurisdiction)
            .all()
        let processed = CredentialsIndexPage.sorted(
            CredentialsIndexPage.filtered(rows, by: filter),
            by: activeSpec
        )
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            CredentialsIndexPage(
                brand: brand,
                credentials: processed,
                flash: flash,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get("new") { req -> HTMLResponse in
        let (people, jurisdictions) = try await loadCredentialFormDeps(req: req)
        return HTMLResponse {
            CredentialFormPage(
                brand: brand,
                mode: .new,
                form: CredentialFormValues(),
                errors: .none,
                people: people,
                jurisdictions: jurisdictions
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(CredentialPayload.self)) ?? .empty
        let values = payload.values
        let (people, jurisdictions) = try await loadCredentialFormDeps(req: req)
        let errors = validateCredential(values: values, people: people, jurisdictions: jurisdictions)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                CredentialFormPage(
                    brand: brand,
                    mode: .new,
                    form: values,
                    errors: errors,
                    people: people,
                    jurisdictions: jurisdictions
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        let c = Credential()
        applyCredential(values: values, to: c)
        try await c.save(on: db)
        let flash = encodeFlash("Credential \(c.licenseNumber) created.")
        return req.redirect(to: "/admin/credentials?flash=\(flash)", redirectType: .normal)
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let c = try await loadCredential(req: req)
        let (people, jurisdictions) = try await loadCredentialFormDeps(req: req)
        return HTMLResponse {
            CredentialFormPage(
                brand: brand,
                mode: .edit(id: c.id?.uuidString ?? ""),
                form: CredentialFormValues(credential: c),
                errors: .none,
                people: people,
                jurisdictions: jurisdictions
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let c = try await loadCredential(req: req)
        let payload = (try? req.content.decode(CredentialPayload.self)) ?? .empty
        let values = payload.values
        let (people, jurisdictions) = try await loadCredentialFormDeps(req: req)
        let errors = validateCredential(values: values, people: people, jurisdictions: jurisdictions)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                CredentialFormPage(
                    brand: brand,
                    mode: .edit(id: c.id?.uuidString ?? ""),
                    form: values,
                    errors: errors,
                    people: people,
                    jurisdictions: jurisdictions
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        applyCredential(values: values, to: c)
        try await c.save(on: db)
        let flash = encodeFlash("Credential \(c.licenseNumber) updated.")
        return req.redirect(to: "/admin/credentials?flash=\(flash)", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let c = try await loadCredential(req: req)
        let license = c.licenseNumber
        let db = try await requireDatabaseService(req).db
        try await CredentialRepository(database: db).delete(id: c.id!)
        let flash = encodeFlash("Credential \(license) deleted.")
        return req.redirect(to: "/admin/credentials?flash=\(flash)", redirectType: .normal)
    }
}

private struct CredentialPayload: Content {
    var personId: String?
    var jurisdictionId: String?
    var licenseNumber: String?

    static let empty = CredentialPayload(
        personId: nil,
        jurisdictionId: nil,
        licenseNumber: nil
    )

    var values: CredentialFormValues {
        CredentialFormValues(
            personId: personId ?? "",
            jurisdictionId: jurisdictionId ?? "",
            licenseNumber: licenseNumber ?? ""
        )
    }
}

private func validateCredential(
    values: CredentialFormValues,
    people: [Person],
    jurisdictions: [Jurisdiction]
) -> CredentialFormErrors {
    var summary: [String] = []
    let personError: String?
    if values.personId.isEmpty || !people.contains(where: { $0.id?.uuidString == values.personId }) {
        personError = "Pick a person."
        summary.append(personError!)
    } else {
        personError = nil
    }
    let jurisdictionError: String?
    if values.jurisdictionId.isEmpty
        || !jurisdictions.contains(where: { $0.id?.uuidString == values.jurisdictionId })
    {
        jurisdictionError = "Pick a jurisdiction."
        summary.append(jurisdictionError!)
    } else {
        jurisdictionError = nil
    }
    let licenseError: String?
    let trimmedLicense = values.licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedLicense.isEmpty {
        licenseError = "License number is required."
        summary.append(licenseError!)
    } else {
        licenseError = nil
    }
    return CredentialFormErrors(
        personId: personError,
        jurisdictionId: jurisdictionError,
        licenseNumber: licenseError,
        summary: summary
    )
}

private func applyCredential(values: CredentialFormValues, to c: Credential) {
    if let pid = UUID(uuidString: values.personId) { c.$person.id = pid }
    if let jid = UUID(uuidString: values.jurisdictionId) { c.$jurisdiction.id = jid }
    c.licenseNumber = values.licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func loadCredential(req: Request) async throws -> Credential {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid credential id.")
    }
    let db = try await requireDatabaseService(req).db
    guard let c = try await CredentialRepository(database: db).find(id: id) else {
        throw Abort(.notFound)
    }
    return c
}

private func loadCredentialFormDeps(req: Request) async throws -> ([Person], [Jurisdiction]) {
    let db = try await requireDatabaseService(req).db
    async let people = Person.query(on: db).sort(\.$name).all()
    async let jurisdictions = Jurisdiction.query(on: db).sort(\.$name).all()
    return try await (people, jurisdictions)
}

// MARK: - Invoices

private func registerInvoiceRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "invoices")

    group.get { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await Invoice.query(on: db)
            .sort(\.$invoiceDate, .descending)
            .all()
        let page = AdminPagination.parsePage(try? req.query.get(String.self, at: "page"))
        let pageRows = AdminPagination.slice(rows, page: page)
        let pagination = AdminPagination(
            page: page,
            pageSize: AdminPagination.defaultPageSize,
            total: rows.count,
            basePath: "/admin/invoices",
            queryItems: []
        )
        return HTMLResponse {
            InvoicesIndexPage(brand: brand, invoices: pageRows, pagination: pagination)
        }
    }

    group.get(":id") { req -> HTMLResponse in
        guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
            throw Abort(.badRequest)
        }
        let db = try await requireDatabaseService(req).db
        guard let inv = try await Invoice.find(id, on: db) else {
            throw Abort(.notFound)
        }
        let lines = try await InvoiceLineItem.query(on: db)
            .filter(\.$invoice.$id == id)
            .sort(\.$lineNumber)
            .all()
        return HTMLResponse {
            InvoiceShowPage(brand: brand, invoice: inv, lineItems: lines)
        }
    }
}

// MARK: - Billing profiles

private func registerBillingProfileRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "billing-profiles") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await EntityBillingProfile.query(on: db)
            .with(\.$entity)
            .all()
        return HTMLResponse {
            BillingProfilesIndexPage(brand: brand, profiles: rows)
        }
    }
}

// MARK: - Mailrooms (full CRUD)

private func registerMailroomRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "mailrooms")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: MailroomsIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? MailroomsIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let db = try await requireDatabaseService(req).db
        let rows = try await Mailroom.query(on: db).all()
        let processed = MailroomsIndexPage.sorted(
            MailroomsIndexPage.filtered(rows, by: filter),
            by: activeSpec
        )
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            MailroomsIndexPage(
                brand: brand,
                mailrooms: processed,
                flash: flash,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get("new") { _ -> HTMLResponse in
        HTMLResponse {
            MailroomFormPage(
                brand: brand,
                mode: .new,
                form: MailroomFormValues(),
                errors: .none
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(MailroomPayload.self)) ?? .empty
        let values = payload.values
        let errors = validateMailroom(values: values)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                MailroomFormPage(brand: brand, mode: .new, form: values, errors: errors)
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        let m = Mailroom()
        applyMailroom(values: values, to: m)
        try await m.save(on: db)
        let flash = encodeFlash("Mailroom \(m.name) created.")
        return req.redirect(to: "/admin/mailrooms?flash=\(flash)", redirectType: .normal)
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let m = try await loadMailroom(req: req)
        return HTMLResponse {
            MailroomFormPage(
                brand: brand,
                mode: .edit(id: m.id?.uuidString ?? ""),
                form: MailroomFormValues(mailroom: m),
                errors: .none
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let m = try await loadMailroom(req: req)
        let payload = (try? req.content.decode(MailroomPayload.self)) ?? .empty
        let values = payload.values
        let errors = validateMailroom(values: values)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                MailroomFormPage(
                    brand: brand,
                    mode: .edit(id: m.id?.uuidString ?? ""),
                    form: values,
                    errors: errors
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        applyMailroom(values: values, to: m)
        try await m.save(on: db)
        let flash = encodeFlash("Mailroom \(m.name) updated.")
        return req.redirect(to: "/admin/mailrooms?flash=\(flash)", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let m = try await loadMailroom(req: req)
        let name = m.name
        let db = try await requireDatabaseService(req).db
        try await MailroomRepository(database: db).delete(id: m.id!)
        let flash = encodeFlash("Mailroom \(name) deleted.")
        return req.redirect(to: "/admin/mailrooms?flash=\(flash)", redirectType: .normal)
    }
}

private struct MailroomPayload: Content {
    var name: String?
    var mailboxStart: String?
    var mailboxEnd: String?
    var capacity: String?

    static let empty = MailroomPayload(
        name: nil,
        mailboxStart: nil,
        mailboxEnd: nil,
        capacity: nil
    )

    var values: MailroomFormValues {
        MailroomFormValues(
            name: name ?? "",
            mailboxStart: mailboxStart ?? "",
            mailboxEnd: mailboxEnd ?? "",
            capacity: capacity ?? ""
        )
    }
}

private func validateMailroom(values: MailroomFormValues) -> MailroomFormErrors {
    var summary: [String] = []
    let nameError: String? =
        values.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "Name is required." : nil
    let startError: String? =
        Int(values.mailboxStart) == nil ? "Mailbox start must be an integer." : nil
    let endError: String? =
        Int(values.mailboxEnd) == nil ? "Mailbox end must be an integer." : nil
    let capacityError: String?
    let trimmedCapacity = values.capacity.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedCapacity.isEmpty && Int(trimmedCapacity) == nil {
        capacityError = "Capacity, if set, must be an integer."
    } else {
        capacityError = nil
    }
    if let nameError { summary.append(nameError) }
    if let startError { summary.append(startError) }
    if let endError { summary.append(endError) }
    if let capacityError { summary.append(capacityError) }
    return MailroomFormErrors(
        name: nameError,
        mailboxStart: startError,
        mailboxEnd: endError,
        capacity: capacityError,
        summary: summary
    )
}

private func applyMailroom(values: MailroomFormValues, to m: Mailroom) {
    m.name = values.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let start = Int(values.mailboxStart) { m.mailboxStart = start }
    if let end = Int(values.mailboxEnd) { m.mailboxEnd = end }
    let trimmedCapacity = values.capacity.trimmingCharacters(in: .whitespacesAndNewlines)
    m.capacity = trimmedCapacity.isEmpty ? nil : Int(trimmedCapacity)
}

private func loadMailroom(req: Request) async throws -> Mailroom {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest)
    }
    let db = try await requireDatabaseService(req).db
    guard let m = try await MailroomRepository(database: db).find(id: id) else {
        throw Abort(.notFound)
    }
    return m
}

// MARK: - Users + UserRoleAudit (read-only)

private func registerUserRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "users") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await User.query(on: db).with(\.$person).sort(\.$role).all()
        return HTMLResponse { UsersIndexPage(brand: brand, users: rows) }
    }
    app.get("admin", "user-role-audit") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await UserRoleAudit.query(on: db)
            .with(\.$user) { $0.with(\.$person) }
            .with(\.$changedByUser) { $0.with(\.$person) }
            .sort(\.$insertedAt, .descending)
            .all()
        let page = AdminPagination.parsePage(try? req.query.get(String.self, at: "page"))
        let pageRows = AdminPagination.slice(rows, page: page)
        let pagination = AdminPagination(
            page: page,
            pageSize: AdminPagination.defaultPageSize,
            total: rows.count,
            basePath: "/admin/user-role-audit",
            queryItems: []
        )
        return HTMLResponse {
            UserRoleAuditIndexPage(brand: brand, audits: pageRows, pagination: pagination)
        }
    }
}

// MARK: - Share classes / issuances (read-only)

private func registerShareEquityRoutes(_ app: Application, brand: any Brand) {
    app.get("admin", "share-classes") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await ShareClass.query(on: db)
            .with(\.$entity)
            .sort(\.$priority)
            .all()
        return HTMLResponse { ShareClassesIndexPage(brand: brand, classes: rows) }
    }
    app.get("admin", "share-issuances") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let rows = try await ShareIssuance.query(on: db)
            .with(\.$entity)
            .all()
        return HTMLResponse { ShareIssuancesIndexPage(brand: brand, issuances: rows) }
    }
}

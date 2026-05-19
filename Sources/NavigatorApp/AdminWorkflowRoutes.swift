import FluentKit
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Registers routes for the workflow surface — `/admin/templates`,
/// `/admin/questions`, and `/admin/notations`.
///
/// Templates and Notations are read-only in the admin because they are
/// driven by git sync and the workflow engine respectively. Questions
/// are still authored manually, so they keep full CRUD.
func registerAdminWorkflowRoutes(_ app: Application, brand: any Brand) {
    registerTemplatesReadRoutes(app, brand: brand)
    registerQuestionsCRUDRoutes(app, brand: brand)
    registerNotationsReadRoutes(app, brand: brand)
}

// MARK: - Templates (read-only)

private func registerTemplatesReadRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "templates")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: TemplatesIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? TemplatesIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let rows = try await Template.query(on: db).all()
        let processed = TemplatesIndexPage.sorted(
            TemplatesIndexPage.filtered(rows, by: filter),
            by: activeSpec
        )
        return HTMLResponse {
            TemplatesIndexPage(
                brand: brand,
                templates: processed,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get(":id") { req -> HTMLResponse in
        guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
            throw Abort(.badRequest, reason: "Invalid template id.")
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        guard let t = try await Template.find(id, on: db) else {
            throw Abort(.notFound)
        }
        let activity = loadTemplateActivity(template: t)
        return HTMLResponse {
            TemplateShowPage(brand: brand, template: t, activity: activity)
        }
    }
}

// MARK: - Questions (full CRUD)

private func registerQuestionsCRUDRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "questions")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: QuestionsIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? QuestionsIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let rows = try await Question.query(on: db).all()
        let processed = QuestionsIndexPage.sorted(
            QuestionsIndexPage.filtered(rows, by: filter),
            by: activeSpec
        )
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            QuestionsIndexPage(
                brand: brand,
                questions: processed,
                flash: flash,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get("new") { _ -> HTMLResponse in
        HTMLResponse {
            QuestionFormPage(
                brand: brand,
                mode: .new,
                form: QuestionFormValues(),
                errors: .none
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(QuestionPayload.self)) ?? .empty
        let values = payload.values
        let errors = await validateQuestion(req: req, values: values, existingID: nil)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                QuestionFormPage(brand: brand, mode: .new, form: values, errors: errors)
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let q = Question()
        applyQuestion(values: values, to: q)
        try await q.save(on: db)
        let flash = encodeFlash("Question \(q.code) created.")
        return req.redirect(to: "/admin/questions?flash=\(flash)", redirectType: .normal)
    }

    group.get(":id") { req -> HTMLResponse in
        let q = try await loadQuestion(req: req)
        return HTMLResponse { QuestionShowPage(brand: brand, question: q) }
    }

    group.get(":id", "edit") { req -> HTMLResponse in
        let q = try await loadQuestion(req: req)
        return HTMLResponse {
            QuestionFormPage(
                brand: brand,
                mode: .edit(id: q.id?.uuidString ?? ""),
                form: QuestionFormValues(question: q),
                errors: .none
            )
        }
    }

    group.on(.PATCH, ":id") { req -> Response in
        let q = try await loadQuestion(req: req)
        let payload = (try? req.content.decode(QuestionPayload.self)) ?? .empty
        let values = payload.values
        let errors = await validateQuestion(req: req, values: values, existingID: q.id)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                QuestionFormPage(
                    brand: brand,
                    mode: .edit(id: q.id?.uuidString ?? ""),
                    form: values,
                    errors: errors
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        applyQuestion(values: values, to: q)
        try await q.save(on: db)
        let flash = encodeFlash("Question \(q.code) updated.")
        return req.redirect(to: "/admin/questions?flash=\(flash)", redirectType: .normal)
    }

    group.on(.DELETE, ":id") { req -> Response in
        let q = try await loadQuestion(req: req)
        let code = q.code
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        try await QuestionRepository(database: db).delete(id: q.id!)
        let flash = encodeFlash("Question \(code) deleted.")
        return req.redirect(to: "/admin/questions?flash=\(flash)", redirectType: .normal)
    }
}

private struct QuestionPayload: Content {
    var code: String?
    var prompt: String?
    var questionType: String?
    var helpText: String?

    static let empty = QuestionPayload(code: nil, prompt: nil, questionType: nil, helpText: nil)

    var values: QuestionFormValues {
        QuestionFormValues(
            code: code ?? "",
            prompt: prompt ?? "",
            questionType: questionType ?? "",
            helpText: helpText ?? ""
        )
    }
}

private func validateQuestion(
    req: Request,
    values: QuestionFormValues,
    existingID: UUID?
) async -> QuestionFormErrors {
    var summary: [String] = []
    let code = values.code.trimmingCharacters(in: .whitespacesAndNewlines)
    let prompt = values.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    var codeError: String? = nil
    var promptError: String? = nil
    var typeError: String? = nil
    if code.isEmpty {
        codeError = "Code is required."
        summary.append("Code is required.")
    } else if let db = try? await requireDatabaseService(req).db,
        let existing = try? await Question.query(on: db).filter(\.$code == code).first(),
        existing.id != existingID
    {
        codeError = "Code is already in use."
        summary.append("Code is already in use.")
    }
    if prompt.isEmpty {
        promptError = "Prompt is required."
        summary.append("Prompt is required.")
    }
    if values.typeEnum == nil {
        typeError = "Pick a question type."
        summary.append("Pick a question type.")
    }
    return QuestionFormErrors(
        code: codeError,
        prompt: promptError,
        questionType: typeError,
        helpText: nil,
        summary: summary
    )
}

private func applyQuestion(values: QuestionFormValues, to q: Question) {
    q.code = values.code.trimmingCharacters(in: .whitespacesAndNewlines)
    q.prompt = values.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    if let type = values.typeEnum { q.questionType = type }
    let trimmedHelp = values.helpText.trimmingCharacters(in: .whitespacesAndNewlines)
    q.helpText = trimmedHelp.isEmpty ? nil : trimmedHelp
}

private func loadQuestion(req: Request) async throws -> Question {
    guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
        throw Abort(.badRequest, reason: "Invalid question id.")
    }
    let databaseService = try requireDatabaseService(req)
    let db = try await databaseService.db
    guard let q = try await QuestionRepository(database: db).find(id: id) else {
        throw Abort(.notFound, reason: "Question not found.")
    }
    return q
}

// MARK: - Notations (read-only)

private func registerNotationsReadRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "notations")

    group.get { req -> HTMLResponse in
        let raw = try? req.query.get(String.self, at: "sort")
        let parsed = SortSpec.parse(raw)
        let spec: SortSpec
        do {
            spec = try parsed.validated(against: NotationsIndexPage.sortableKeys)
        } catch let SortError.unsupportedField(key) {
            throw Abort(.badRequest, reason: "Unsupported sort field: \(key)")
        }
        let activeSpec = spec.fields.isEmpty ? NotationsIndexPage.defaultSort : spec
        let filter = (try? req.query.get(String.self, at: "q")) ?? ""
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let rows = try await Notation.query(on: db)
            .with(\.$template)
            .with(\.$person)
            .with(\.$entity)
            .all()
        let processed = NotationsIndexPage.sorted(
            NotationsIndexPage.filtered(rows, by: filter),
            by: activeSpec
        )
        return HTMLResponse {
            NotationsIndexPage(
                brand: brand,
                notations: processed,
                sort: activeSpec,
                filter: filter
            )
        }
    }

    group.get(":id") { req -> HTMLResponse in
        guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
            throw Abort(.badRequest, reason: "Invalid notation id.")
        }
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        guard
            let n = try await Notation.query(on: db)
                .with(\.$template)
                .with(\.$person)
                .with(\.$entity)
                .filter(\.$id == id)
                .first()
        else { throw Abort(.notFound) }
        let activity = loadNotationActivity(notation: n)
        return HTMLResponse {
            NotationShowPage(brand: brand, notation: n, activity: activity)
        }
    }
}

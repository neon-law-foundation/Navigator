import FluentKit
import Foundation
import HTTPTypes
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorOIDCMiddleware
import OpenAPIRuntime

struct APIHandler: APIProtocol {
    let db: any Database
    let databaseService: DatabaseService
    let emailService: EmailService
    let storageService: StorageService
    let authMiddleware: any ServerMiddleware
    let mailIngestSecret: String

    // MARK: - Questions

    func listQuestions(
        _ input: Operations.listQuestions.Input
    ) async throws -> Operations.listQuestions.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let db = try await databaseService.db
        let questions = try await Question.query(on: db).all()
        let sorted = questions.sorted { $0.code < $1.code }
        let dtos = sorted.map(questionDTO(from:))
        return .ok(.init(body: .json(dtos)))
    }

    // MARK: - Dashboard / Account / Mailboxes

    func getDashboard(
        _ input: Operations.getDashboard.Input
    ) async throws -> Operations.getDashboard.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getAccount(
        _ input: Operations.getAccount.Input
    ) async throws -> Operations.getAccount.Output {
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let db = try await databaseService.db
        guard
            let user = try await User.query(on: db)
                .filter(\.$sub == authenticatedUser.sub)
                .with(\.$person)
                .first()
        else {
            return .undocumented(statusCode: 401, .init())
        }
        let summary = Components.Schemas.AccountSummary(
            id: try user.requireID(),
            email: user.person.email,
            name: user.person.name,
            role: Components.Schemas.UserRole(rawValue: user.role.rawValue)!
        )
        return .ok(.init(body: .json(summary)))
    }

    func updateAccount(
        _ input: Operations.updateAccount.Input
    ) async throws -> Operations.updateAccount.Output {
        .undocumented(statusCode: 501, .init())
    }

    func getMailboxes(
        _ input: Operations.getMailboxes.Input
    ) async throws -> Operations.getMailboxes.Output {
        .undocumented(statusCode: 501, .init())
    }

    // MARK: - Projects

    func listProjects(
        _ input: Operations.listProjects.Input
    ) async throws -> Operations.listProjects.Output {
        guard let role = RequestLocals.userRole else {
            return .undocumented(statusCode: 401, .init())
        }
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let db = try await databaseService.db
        let projectRepository = ProjectRepository(database: db)

        let projects: [Project]
        switch role {
        case .admin:
            projects = try await projectRepository.findAll()
        case .staff, .client:
            guard
                let user = try await User.query(on: db)
                    .filter(\.$sub == authenticatedUser.sub)
                    .with(\.$person)
                    .first()
            else {
                return .undocumented(statusCode: 401, .init())
            }
            let personId = user.$person.id
            let roleRepo = PersonProjectRoleRepository(database: db)
            let projectIds = try await roleRepo.findProjectIds(forPersonId: personId)
            projects = try await projectRepository.find(ids: projectIds)
        }

        let summaries = try projects.map { project in
            Components.Schemas.ProjectSummary(
                id: try project.requireID(),
                codename: project.codename,
                title: project.title,
                status: project.status.flatMap {
                    Components.Schemas.ProjectSummary.statusPayload(rawValue: $0.rawValue)
                },
                projectType: project.projectType.flatMap {
                    Components.Schemas.ProjectSummary.projectTypePayload(rawValue: $0.rawValue)
                },
                insertedAt: project.insertedAt
            )
        }
        return .ok(.init(body: .json(summaries)))
    }

    func getProject(
        _ input: Operations.getProject.Input
    ) async throws -> Operations.getProject.Output {
        guard let role = RequestLocals.userRole else {
            return .undocumented(statusCode: 401, .init())
        }
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let projectID = input.path.id
        let db = try await databaseService.db
        let projectRepository = ProjectRepository(database: db)
        guard let project = try await projectRepository.find(id: projectID) else {
            return .notFound(.init())
        }

        switch role {
        case .admin:
            break
        case .staff, .client:
            guard
                let user = try await User.query(on: db)
                    .filter(\.$sub == authenticatedUser.sub)
                    .with(\.$person)
                    .first()
            else {
                return .undocumented(statusCode: 401, .init())
            }
            let personId = user.$person.id
            let roleRepo = PersonProjectRoleRepository(database: db)
            let projectIds = try await roleRepo.findProjectIds(forPersonId: personId)
            guard projectIds.contains(projectID) else {
                return .notFound(.init())
            }
        }

        let documents = try await Document.query(on: db)
            .filter(\.$project.$id == projectID)
            .with(\.$blob)
            .all()
        let files = try documents.map { doc in
            Components.Schemas.ProjectFile(
                id: try doc.requireID(),
                title: doc.title,
                s3Key: doc.blob.objectStorageUrl,
                insertedAt: doc.insertedAt
            )
        }
        let detail = Components.Schemas.ProjectDetail(
            id: try project.requireID(),
            codename: project.codename,
            title: project.title,
            status: project.status.flatMap {
                Components.Schemas.ProjectDetail.statusPayload(rawValue: $0.rawValue)
            },
            projectType: project.projectType.flatMap {
                Components.Schemas.ProjectDetail.projectTypePayload(rawValue: $0.rawValue)
            },
            files: files,
            insertedAt: project.insertedAt
        )
        return .ok(.init(body: .json(detail)))
    }

    func createProject(
        _ input: Operations.createProject.Input
    ) async throws -> Operations.createProject.Output {
        guard let role = RequestLocals.userRole else {
            return .undocumented(statusCode: 401, .init())
        }
        guard role == .admin || role == .staff else {
            return .forbidden(.init())
        }
        let body: Components.Schemas.CreateProjectRequest
        switch input.body {
        case .json(let b): body = b
        }
        let db = try await databaseService.db
        let project = Project()
        project.codename = body.codename
        project.title = body.title
        if let pt = body.projectType {
            project.projectType = ProjectType(rawValue: pt.rawValue)
        }
        let projectRepository = ProjectRepository(database: db)
        let saved = try await projectRepository.create(model: project)
        let detail = Components.Schemas.ProjectDetail(
            id: try saved.requireID(),
            codename: saved.codename,
            title: saved.title,
            status: nil,
            projectType: saved.projectType.flatMap {
                Components.Schemas.ProjectDetail.projectTypePayload(rawValue: $0.rawValue)
            },
            files: [],
            insertedAt: saved.insertedAt
        )
        return .ok(.init(body: .json(detail)))
    }

    func listProjectFiles(
        _ input: Operations.listProjectFiles.Input
    ) async throws -> Operations.listProjectFiles.Output {
        guard let role = RequestLocals.userRole else {
            return .undocumented(statusCode: 401, .init())
        }
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let projectID = input.path.id
        let db = try await databaseService.db
        let projectRepository = ProjectRepository(database: db)
        guard let _ = try await projectRepository.find(id: projectID) else {
            return .notFound(.init())
        }

        switch role {
        case .admin:
            break
        case .staff, .client:
            guard
                let user = try await User.query(on: db)
                    .filter(\.$sub == authenticatedUser.sub)
                    .with(\.$person)
                    .first()
            else {
                return .undocumented(statusCode: 401, .init())
            }
            let personId = user.$person.id
            let roleRepo = PersonProjectRoleRepository(database: db)
            let projectIds = try await roleRepo.findProjectIds(forPersonId: personId)
            guard projectIds.contains(projectID) else {
                return .notFound(.init())
            }
        }

        let documents = try await Document.query(on: db)
            .filter(\.$project.$id == projectID)
            .with(\.$blob)
            .all()
        let files = try documents.map { doc in
            Components.Schemas.ProjectFile(
                id: try doc.requireID(),
                title: doc.title,
                s3Key: doc.blob.objectStorageUrl,
                insertedAt: doc.insertedAt
            )
        }
        return .ok(.init(body: .json(files)))
    }

    // MARK: - Formation Notations

    func getFormationNotations(
        _ input: Operations.getFormationNotations.Input
    ) async throws -> Operations.getFormationNotations.Output {
        let db = try await databaseService.db
        let templates = try await Template.query(on: db).all()
        let summaries: [Components.Schemas.NotationSummary] = templates.compactMap { template in
            guard let code = template.code else { return nil }
            return Components.Schemas.NotationSummary(
                code: code,
                title: template.title,
                description: template.description,
                respondentType: template.respondentType.rawValue,
                flowStateCount: template.questionnaire.count,
                alignmentStateCount: template.workflow.count
            )
        }
        return .ok(.init(body: .json(summaries)))
    }

    func createFormationInstance(
        _ input: Operations.createFormationInstance.Input
    ) async throws -> Operations.createFormationInstance.Output {
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let db = try await databaseService.db
        guard
            let user = try await User.query(on: db)
                .filter(\.$sub == authenticatedUser.sub)
                .with(\.$person)
                .first()
        else { return .undocumented(statusCode: 401, .init()) }

        let body: Components.Schemas.CreateFormationInstanceRequest
        switch input.body {
        case .json(let b): body = b
        }

        let notationCode = input.path.notationCode
        guard
            let template = try await Template.query(on: db)
                .filter(\.$code == notationCode)
                .first()
        else { return .undocumented(statusCode: 404, .init()) }

        let templateID = try template.requireID()
        // Nullable UUID body fields stay as inline `type: [string, "null"], format: uuid`
        // because swift-openapi-generator drops the property when the spec uses
        // `oneOf`/`anyOf` against `type: "null"`. Parse the strings here.
        let bodyPersonID: UUID?
        do { bodyPersonID = try parseOptionalUUID(body.respondentPersonID) } catch {
            return .undocumented(statusCode: 400, .init())
        }
        let bodyEntityID: UUID?
        do { bodyEntityID = try parseOptionalUUID(body.respondentEntityID) } catch {
            return .undocumented(statusCode: 400, .init())
        }
        let personID: UUID? = bodyPersonID ?? user.person.id
        let entityID: UUID? = bodyEntityID

        let beginTransitions = template.questionnaire["BEGIN"] ?? [:]
        let firstState: String
        if let explicit = beginTransitions["_"] {
            firstState = explicit
        } else if let first = beginTransitions.values.first {
            firstState = first
        } else {
            firstState = "END"
        }

        let initialEvent = NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: firstState,
            actor: .system,
            at: Date()
        )

        let notation = Notation()
        notation.$template.id = templateID
        notation.$person.id = personID
        notation.$entity.id = entityID
        notation.stateHistory = [initialEvent]
        try await notation.save(on: db)

        let instance = try await buildFlowInstance(notation: notation, template: template, db: db)
        return .ok(.init(body: .json(instance)))
    }

    // MARK: - Formation Instances

    func getFormationInstances(
        _ input: Operations.getFormationInstances.Input
    ) async throws -> Operations.getFormationInstances.Output {
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let db = try await databaseService.db
        guard
            let user = try await User.query(on: db)
                .filter(\.$sub == authenticatedUser.sub)
                .with(\.$person)
                .first()
        else { return .undocumented(statusCode: 401, .init()) }

        let personID = user.person.id
        let notations = try await Notation.query(on: db)
            .filter(\.$person.$id == personID)
            .all()

        let templates = try await Template.query(on: db).all()
        let templateMap: [UUID: Template] = Dictionary(
            uniqueKeysWithValues: templates.compactMap { t -> (UUID, Template)? in
                guard let id = t.id else { return nil }
                return (id, t)
            }
        )

        var instances: [Components.Schemas.FlowInstance] = []
        for notation in notations {
            let templateID = notation.$template.id
            guard let template = templateMap[templateID] else { continue }
            let instance = try await buildFlowInstance(notation: notation, template: template, db: db)
            instances.append(instance)
        }

        return .ok(.init(body: .json(instances)))
    }

    func getFormationInstance(
        _ input: Operations.getFormationInstance.Input
    ) async throws -> Operations.getFormationInstance.Output {
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let db = try await databaseService.db
        guard
            let user = try await User.query(on: db)
                .filter(\.$sub == authenticatedUser.sub)
                .with(\.$person)
                .first()
        else { return .undocumented(statusCode: 401, .init()) }

        let notationID = input.path.id
        guard let notation = try await Notation.find(notationID, on: db) else {
            return .notFound(.init())
        }
        guard notation.$person.id == user.person.id else {
            return .undocumented(statusCode: 403, .init())
        }

        guard let template = try await Template.find(notation.$template.id, on: db) else {
            return .undocumented(statusCode: 500, .init())
        }

        let instance = try await buildFlowInstance(notation: notation, template: template, db: db)
        return .ok(.init(body: .json(instance)))
    }

    // MARK: - Formation Steps

    func submitFormationStep(
        _ input: Operations.submitFormationStep.Input
    ) async throws -> Operations.submitFormationStep.Output {
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        let db = try await databaseService.db
        guard
            let user = try await User.query(on: db)
                .filter(\.$sub == authenticatedUser.sub)
                .with(\.$person)
                .first()
        else { return .undocumented(statusCode: 401, .init()) }

        let notationID = input.path.id
        guard let notation = try await Notation.find(notationID, on: db) else {
            return .notFound(.init())
        }
        guard notation.$person.id == user.person.id else {
            return .undocumented(statusCode: 403, .init())
        }

        guard let template = try await Template.find(notation.$template.id, on: db) else {
            return .undocumented(statusCode: 500, .init())
        }

        let body: Components.Schemas.SubmitFormationStepRequest
        switch input.body {
        case .json(let b): body = b
        }

        let currentState = notation.stateHistory.last?.toState ?? "BEGIN"
        guard currentState == body.stateID else {
            return .undocumented(statusCode: 422, .init())
        }
        guard currentState != "END" else {
            return .undocumented(statusCode: 422, .init())
        }

        let questionnaire = template.questionnaire
        guard let transitions = questionnaire[currentState] else {
            return .undocumented(statusCode: 422, .init())
        }

        let answerPayload = body.answer
        let condition: String
        switch answerPayload._type {
        case "choice":
            condition = answerPayload.choiceValue ?? "continue"
        default:
            condition =
                transitions.keys.contains("continue") ? "continue" : (transitions.keys.first ?? "_")
        }

        guard let nextState = transitions[condition] ?? transitions["_"] ?? transitions.values.first
        else {
            return .undocumented(statusCode: 422, .init())
        }

        let answerValue: String
        switch answerPayload._type {
        case "string":
            answerValue = answerPayload.stringValue ?? ""
        case "choice":
            answerValue = answerPayload.choiceValue ?? ""
        case "multichoice":
            let values = answerPayload.multiChoiceValue ?? []
            answerValue = values.joined(separator: ",")
        case "payload":
            answerValue = answerPayload.payloadValue ?? ""
        default:
            answerValue = answerPayload.stringValue ?? ""
        }

        let personID = user.person.id
        if let personID = personID,
            let question = try await Question.query(on: db).filter(\.$code == currentState).first()
        {
            let answer = Answer()
            answer.$question.id = try question.requireID()
            answer.$person.id = personID
            answer.$entity.id = notation.$entity.id
            answer.value = answerValue
            try await answer.save(on: db)

            let answerID = try answer.requireID()
            var updatedAnswers = notation.answers
            updatedAnswers[currentState] = answerID
            notation.answers = updatedAnswers
        }

        let actor: NotationActor
        if let pid = notation.$person.id {
            actor = .person(id: pid)
        } else if let eid = notation.$entity.id {
            actor = .entity(id: eid)
        } else {
            actor = .system
        }

        let stepEvent = NotationEvent(
            fromState: currentState,
            condition: condition,
            toState: nextState,
            actor: actor,
            at: Date()
        )
        notation.stateHistory = notation.stateHistory + [stepEvent]
        try await notation.save(on: db)

        let instance = try await buildFlowInstance(notation: notation, template: template, db: db)
        return .ok(.init(body: .json(instance)))
    }

    // MARK: - Subscriptions

    func getSubscriptions(
        _ input: Operations.getSubscriptions.Input
    ) async throws -> Operations.getSubscriptions.Output {
        .undocumented(statusCode: 501, .init())
    }

    func createSubscription(
        _ input: Operations.createSubscription.Input
    ) async throws -> Operations.createSubscription.Output {
        .undocumented(statusCode: 501, .init())
    }

    func cancelSubscription(
        _ input: Operations.cancelSubscription.Input
    ) async throws -> Operations.cancelSubscription.Output {
        .undocumented(statusCode: 501, .init())
    }

    // MARK: - Admin: Users

    private func userDetailDTO(from user: User) throws -> Components.Schemas.UserDetail {
        Components.Schemas.UserDetail(
            id: try user.requireID(),
            email: user.person.email,
            role: Components.Schemas.UserRole(rawValue: user.role.rawValue)!,
            personId: user.$person.id,
            insertedAt: user.insertedAt!,
            updatedAt: user.updatedAt ?? user.insertedAt!
        )
    }

    func listUsers(
        _ input: Operations.listUsers.Input
    ) async throws -> Operations.listUsers.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let db = try await databaseService.db
        let limit = min(input.query.limit ?? 50, 200)

        var query = User.query(on: db).with(\.$person)
        if let roleFilter = input.query.role {
            if let role = UserRole(rawValue: roleFilter.rawValue) {
                query = query.filter(\.$role == role)
            }
        }

        let users: [User]
        if let q = input.query.q, !q.isEmpty {
            let lower = q.lowercased()
            let all = try await query.all()
            users = Array(
                all.filter { $0.person.email.lowercased().contains(lower) }.prefix(Int(limit))
            )
        } else {
            users = try await query.limit(Int(limit)).all()
        }

        let summaries = try users.map { user in
            Components.Schemas.UserSummary(
                id: try user.requireID(),
                email: user.person.email,
                role: Components.Schemas.UserRole(rawValue: user.role.rawValue)!,
                insertedAt: user.insertedAt!,
                updatedAt: user.updatedAt ?? user.insertedAt!
            )
        }
        return .ok(.init(body: .json(summaries)))
    }

    func getUser(
        _ input: Operations.getUser.Input
    ) async throws -> Operations.getUser.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let userId = input.path.id
        let db = try await databaseService.db
        guard
            let user = try await User.query(on: db)
                .filter(\.$id == userId)
                .with(\.$person)
                .first()
        else {
            return .notFound(.init())
        }
        return .ok(.init(body: .json(try userDetailDTO(from: user))))
    }

    func updateUserRole(
        _ input: Operations.updateUserRole.Input
    ) async throws -> Operations.updateUserRole.Output {
        guard let authenticatedUser = RequestLocals.authenticatedUser else {
            return .undocumented(statusCode: 401, .init())
        }
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let body: Components.Schemas.UpdateUserRoleRequest
        switch input.body {
        case .json(let b): body = b
        }
        guard let newRole = UserRole(rawValue: body.role.rawValue) else {
            return .undocumented(statusCode: 400, .init())
        }
        let targetId = input.path.id
        let db = try await databaseService.db
        guard
            let targetUser = try await User.query(on: db)
                .filter(\.$id == targetId)
                .with(\.$person)
                .first()
        else {
            return .notFound(.init())
        }
        guard
            let callerUser = try await User.query(on: db)
                .filter(\.$sub == authenticatedUser.sub)
                .first()
        else {
            return .undocumented(statusCode: 401, .init())
        }
        let callerID = try callerUser.requireID()
        let targetID = try targetUser.requireID()
        if callerID == targetID {
            return .undocumented(statusCode: 403, .init())
        }
        let previousRole = targetUser.role
        let audit = UserRoleAudit()
        audit.$user.id = targetID
        audit.$changedByUser.id = callerID
        audit.previousRole = previousRole
        audit.newRole = newRole
        audit.reason = body.reason
        let auditRepo = UserRoleAuditRepository(database: db)
        _ = try await auditRepo.create(model: audit)
        targetUser.role = newRole
        try await targetUser.save(on: db)
        return .ok(.init(body: .json(try userDetailDTO(from: targetUser))))
    }

    func getUserRoleHistory(
        _ input: Operations.getUserRoleHistory.Input
    ) async throws -> Operations.getUserRoleHistory.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let userId = input.path.id
        let db = try await databaseService.db
        guard let _ = try await User.find(userId, on: db) else {
            return .notFound(.init())
        }
        let auditRepo = UserRoleAuditRepository(database: db)
        let entries = try await auditRepo.findByUser(userId: userId)
        let dtos = try entries.map { entry in
            Components.Schemas.RoleAuditEntry(
                id: try entry.requireID(),
                userId: entry.$user.id,
                changedByUserId: entry.$changedByUser.id,
                previousRole: Components.Schemas.UserRole(rawValue: entry.previousRole.rawValue)!,
                newRole: Components.Schemas.UserRole(rawValue: entry.newRole.rawValue)!,
                reason: entry.reason,
                insertedAt: entry.insertedAt!
            )
        }
        return .ok(.init(body: .json(dtos)))
    }

    // MARK: - Inbound Email

    func ingestInboundEmail(
        _ input: Operations.ingestInboundEmail.Input
    ) async throws -> Operations.ingestInboundEmail.Output {
        let body: Components.Schemas.InboundEmailRequest
        switch input.body {
        case .json(let b): body = b
        }

        let signature = input.headers.X_hyphen_NLF_hyphen_Signature
        let payloadData = try HMACVerifier.encoder.encode(body)
        guard
            HMACVerifier.verify(
                payload: payloadData,
                signature: signature,
                secret: mailIngestSecret
            )
        else {
            return .undocumented(statusCode: 401, .init())
        }

        let db = try await databaseService.db
        let service = EmailIngestionService(database: db)
        let result = try await service.ingest(body)

        switch result {
        case .created(let message):
            let response = Components.Schemas.IngestedEmail(
                id: message.id!,
                messageId: message.messageId,
                threadId: message.threadId
            )
            return .ok(.init(body: .json(response)))
        case .duplicate(let existing):
            let response = Components.Schemas.IngestedEmail(
                id: existing.id!,
                messageId: existing.messageId,
                threadId: existing.threadId
            )
            return .conflict(.init(body: .json(response)))
        }
    }

    // MARK: - People

    func listPeople(
        _ input: Operations.listPeople.Input
    ) async throws -> Operations.listPeople.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let db = try await databaseService.db
        let people = try await Person.query(on: db).all()
        let dtos = people.map { person in
            Components.Schemas.Person(
                id: person.id?.uuidString,
                name: person.name,
                email: person.email,
                insertedAt: person.insertedAt,
                updatedAt: person.updatedAt
            )
        }
        return .ok(.init(body: .json(dtos)))
    }

    // MARK: - Questions CRUD

    func createQuestion(
        _ input: Operations.createQuestion.Input
    ) async throws -> Operations.createQuestion.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let body: Components.Schemas.Question
        switch input.body {
        case .json(let b): body = b
        }
        let db = try await databaseService.db
        let question = Question()
        question.prompt = body.prompt
        question.questionType = QuestionType(rawValue: body.questionType.rawValue) ?? .string
        question.code = body.code
        question.helpText = body.helpText
        question.choices = body.choices?.additionalProperties
        try await question.save(on: db)
        return .ok(.init(body: .json(questionDTO(from: question))))
    }

    func updateQuestion(
        _ input: Operations.updateQuestion.Input
    ) async throws -> Operations.updateQuestion.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let questionID = input.path.id
        let db = try await databaseService.db
        guard let question = try await Question.find(questionID, on: db) else {
            return .notFound(.init())
        }
        let body: Components.Schemas.UpdateQuestionRequest
        switch input.body {
        case .json(let b): body = b
        }
        if let prompt = body.prompt { question.prompt = prompt }
        if let code = body.code { question.code = code }
        if let helpText = body.helpText { question.helpText = helpText }
        if let choices = body.choices { question.choices = choices.additionalProperties }
        if let qTypeStr = body.questionType {
            question.questionType = QuestionType(rawValue: qTypeStr) ?? .string
        }
        try await question.save(on: db)
        return .ok(.init(body: .json(questionDTO(from: question))))
    }

    func deleteQuestion(
        _ input: Operations.deleteQuestion.Input
    ) async throws -> Operations.deleteQuestion.Output {
        guard RequestLocals.userRole == .admin else {
            return .undocumented(statusCode: 403, .init())
        }
        let questionID = input.path.id
        let db = try await databaseService.db
        guard let question = try await Question.find(questionID, on: db) else {
            return .notFound(.init())
        }
        try await question.delete(on: db)
        return .ok(.init())
    }

    // MARK: - Private helpers

    private func questionDTO(from question: Question) -> Components.Schemas.Question {
        let qType =
            Components.Schemas.QuestionType(rawValue: question.questionType.rawValue) ?? .string
        let choicesPayload = question.choices.map {
            Components.Schemas.Question.choicesPayload(additionalProperties: $0)
        }
        return Components.Schemas.Question(
            id: question.id?.uuidString,
            code: question.code,
            prompt: question.prompt,
            questionType: qType,
            helpText: question.helpText,
            choices: choicesPayload,
            insertedAt: question.insertedAt,
            updatedAt: question.updatedAt
        )
    }

    private struct InvalidUUIDString: Error {}

    private func parseOptionalUUID(_ raw: String?) throws -> UUID? {
        guard let raw else { return nil }
        guard let parsed = UUID(uuidString: raw) else { throw InvalidUUIDString() }
        return parsed
    }

    private func buildFlowInstance(
        notation: Notation,
        template: Template,
        db: Database
    ) async throws -> Components.Schemas.FlowInstance {
        let id = try notation.requireID()
        let questionnaire = template.questionnaire

        let currentState = notation.stateHistory.last?.toState ?? "BEGIN"
        let isFlowComplete = currentState == "END"

        let nonSentinelStates = questionnaire.keys.filter { $0 != "BEGIN" && $0 != "END" }
        let totalFlowStates = max(1, nonSentinelStates.count)
        let answeredCount = max(0, notation.stateHistory.count - 1)
        let progressPercent = Double(answeredCount) / Double(totalFlowStates)

        let currentStep: Components.Schemas.StateDescriptor?
        if isFlowComplete {
            currentStep = nil
        } else {
            currentStep = try await buildStateDescriptor(stateName: currentState, db: db)
        }

        let history: [Components.Schemas.StepHistory] = notation.stateHistory
            .filter { $0.fromState != "BEGIN" }
            .map { event in
                let actorRole: String
                switch event.actor {
                case .system: actorRole = "system"
                case .person: actorRole = "client"
                case .entity: actorRole = "client"
                }
                return Components.Schemas.StepHistory(
                    stateID: event.fromState,
                    questionCode: event.fromState,
                    answeredAt: event.at,
                    actorRole: actorRole
                )
            }

        return Components.Schemas.FlowInstance(
            id: id,
            notationCode: template.code ?? "",
            status: isFlowComplete ? .completed : .started,
            kind: .client,
            currentState: isFlowComplete ? nil : currentState,
            progressStage: isFlowComplete ? nil : currentState,
            progressPercent: progressPercent,
            isFlowComplete: isFlowComplete,
            isFormationComplete: false,
            isCompleted: isFlowComplete,
            currentStep: currentStep,
            history: history
        )
    }

    private func buildStateDescriptor(
        stateName: String,
        db: Database
    ) async throws -> Components.Schemas.StateDescriptor? {
        guard
            let question = try await Question.query(on: db)
                .filter(\.$code == stateName)
                .first()
        else { return nil }

        let kind = componentKind(for: question.questionType)
        let allowsMultiple = question.questionType == .multiSelect
        let choices: [Components.Schemas.ComponentChoice]? = question.choices.map { dict in
            dict.map { Components.Schemas.ComponentChoice(value: $0.key, label: $0.value) }
        }

        let component = Components.Schemas.ComponentMetadata(
            kind: kind,
            allowsMultipleSelection: allowsMultiple,
            choices: choices
        )

        return Components.Schemas.StateDescriptor(
            id: stateName,
            questionCode: stateName,
            contextTokens: [],
            prompt: question.prompt,
            helpText: question.helpText,
            component: component
        )
    }

    private func componentKind(for questionType: QuestionType) -> String {
        switch questionType {
        case .string, .secret, .phone, .ssn, .ein, .number, .file:
            return "singleLineText"
        case .email:
            return "singleLineText"
        case .text:
            return "multiLineText"
        case .radio:
            return "radio"
        case .select:
            return "picker"
        case .multiSelect:
            return "multiSelect"
        case .yesNo:
            return "toggle"
        case .date, .datetime:
            return "date"
        case .address:
            return "registeredAgent"
        case .org:
            return "organizationLookup"
        case .person:
            return "organizationLookup"
        }
    }
}

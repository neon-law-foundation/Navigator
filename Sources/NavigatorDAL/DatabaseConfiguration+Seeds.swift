import FluentKit
import Foundation
import Logging
import NavigatorRules

private enum GitRepositorySeedError: Error {
    case missingProject
}

// MARK: - Seed Insert Functions

extension NavigatorDALConfiguration {

    // MARK: - Project

    public static func insertProject(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let codename = record["codename"] as? String ?? ""

        if !lookupFields.isEmpty {
            if let existing = try await Project.query(on: database)
                .filter(\.$codename == codename)
                .first()
            {
                try await existing.save(on: database)
                return
            }
        }

        let project = Project()
        project.codename = codename
        try await project.save(on: database)
    }

    // MARK: - GitRepository

    public static func insertGitRepository(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let repositoryName = record["repository_name"] as? String ?? ""

        let projectID: UUID
        if let projectDict = record["project"] as? [String: Any],
            let codename = projectDict["codename"] as? String,
            let project = try await Project.query(on: database)
                .filter(\.$codename == codename)
                .first()
        {
            projectID = project.id!
        } else {
            throw GitRepositorySeedError.missingProject
        }

        if !lookupFields.isEmpty {
            if let existing = try await GitRepository.query(on: database)
                .filter(\.$repositoryName == repositoryName)
                .first()
            {
                if let awsAccountID = record["aws_account_id"] as? String {
                    existing.awsAccountID = awsAccountID
                }
                if let awsRegion = record["aws_region"] as? String {
                    existing.awsRegion = awsRegion
                }
                if let codecommitRepositoryID = record["codecommit_repository_id"] as? String {
                    existing.codecommitRepositoryID = codecommitRepositoryID
                }
                if let repositoryARN = record["repository_arn"] as? String {
                    existing.repositoryARN = repositoryARN
                }
                existing.description = record["description"] as? String
                existing.$project.id = projectID
                try await existing.save(on: database)
                return
            }
        }

        let gitRepository = GitRepository()
        gitRepository.repositoryName = repositoryName
        gitRepository.awsAccountID = record["aws_account_id"] as? String ?? ""
        gitRepository.awsRegion = record["aws_region"] as? String ?? ""
        gitRepository.codecommitRepositoryID = record["codecommit_repository_id"] as? String ?? ""
        gitRepository.repositoryARN = record["repository_arn"] as? String ?? ""
        gitRepository.description = record["description"] as? String
        gitRepository.$project.id = projectID
        try await gitRepository.save(on: database)
    }

    // MARK: - Template Examples

    /// Derives the template code from a file URL relative to the Examples base directory.
    ///
    /// Path components are joined with `__` and the result is lowercased, so
    /// `Trusts/nevada.md` becomes `trusts__nevada`.
    ///
    /// - Parameters:
    ///   - fileURL: The `.md` file URL.
    ///   - baseURL: The Examples directory URL.
    /// - Returns: The derived code string.
    public static func exampleCode(for fileURL: URL, relativeTo baseURL: URL) -> String {
        let basePath = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        let filePath = fileURL.path
        let relativePath =
            filePath.hasPrefix(basePath)
            ? String(filePath.dropFirst(basePath.count))
            : fileURL.lastPathComponent
        let withoutExtension = (relativePath as NSString).deletingPathExtension
        return withoutExtension.replacingOccurrences(of: "/", with: "__").lowercased()
    }

    public static func seedNotationsFromExamples(on database: Database, logger: Logger) async throws {
        guard
            let gitRepo = try await GitRepository.query(on: database)
                .filter(\.$repositoryName == "navigator-examples")
                .first()
        else {
            logger.warning("No 'navigator-examples' git repository found, skipping template seeding")
            return
        }

        guard let repoID = gitRepo.id else {
            logger.warning("Git repository has no ID, skipping template seeding")
            return
        }

        guard let examplesURL = Bundle.module.resourceURL?.appendingPathComponent("Examples") else {
            logger.warning("Examples directory not found in bundle, skipping template seeding")
            return
        }

        guard
            let enumerator = FileManager.default.enumerator(
                at: examplesURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            logger.warning("Could not enumerate Examples directory")
            return
        }

        let fileURLs = enumerator.allObjects.compactMap { $0 as? URL }.filter {
            $0.pathExtension == "md"
        }

        let parser = FrontmatterParser()
        let service = TemplateService(database: database)

        for fileURL in fileURLs {

            logger.info("Seeding template from \(fileURL.lastPathComponent)")

            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)

                guard let yamlStruct = try parser.parseYAML(content, as: ExampleTemplateYAML.self)
                else {
                    logger.warning("No frontmatter in \(fileURL.lastPathComponent), skipping")
                    continue
                }

                guard let title = yamlStruct.title, !title.isEmpty else {
                    logger.warning("Missing title in \(fileURL.lastPathComponent), skipping")
                    continue
                }

                guard let respondentTypeRaw = yamlStruct.respondentType,
                    let respondentType = RespondentType(rawValue: respondentTypeRaw)
                else {
                    logger.warning(
                        "Missing/invalid respondent_type in \(fileURL.lastPathComponent), skipping"
                    )
                    continue
                }

                guard let (frontmatter, markdownContent) = parser.parse(content) else {
                    logger.warning("Could not parse frontmatter in \(fileURL.lastPathComponent), skipping")
                    continue
                }

                let code = exampleCode(for: fileURL, relativeTo: examplesURL)
                let description = yamlStruct.description ?? ""

                _ = try await service.createVersion(
                    gitRepositoryID: repoID,
                    code: code,
                    version: "seed-v1",
                    title: title,
                    description: description,
                    respondentType: respondentType,
                    markdownContent: markdownContent,
                    frontmatter: frontmatter,
                    questionnaire: yamlStruct.questionnaire ?? [:],
                    workflow: yamlStruct.workflow ?? [:],
                    ownerID: nil
                )

                logger.info("Seeded template: \(code)")
            } catch TemplateError.versionAlreadyExists {
                logger.debug("Template already seeded, skipping: \(fileURL.lastPathComponent)")
            } catch TemplateError.titleAlreadyExists {
                logger.debug(
                    "Template title already exists, skipping: \(fileURL.lastPathComponent)"
                )
            } catch {
                logger.error(
                    "Failed to seed template from \(fileURL.lastPathComponent): \(error)"
                )
            }
        }
    }

    // MARK: - Jurisdiction

    public static func insertJurisdiction(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""
        let code = record["code"] as? String ?? ""

        if !lookupFields.isEmpty {
            var query = Jurisdiction.query(on: database)

            if lookupFields.contains("name") && !name.isEmpty {
                query = query.filter(\.$name == name)
            }

            if lookupFields.contains("code") && !code.isEmpty {
                query = query.filter(\.$code == code)
            }

            if let existing = try await query.first() {
                existing.name = name.isEmpty ? existing.name : name
                existing.code = code.isEmpty ? existing.code : code
                if let jurisdictionTypeString = record["jurisdiction_type"] as? String,
                    let jurisdictionType = JurisdictionType(rawValue: jurisdictionTypeString)
                {
                    existing.jurisdictionType = jurisdictionType
                }
                try await existing.save(on: database)
                return
            }
        }

        let jurisdiction = Jurisdiction()
        jurisdiction.code = code
        jurisdiction.name = name
        if let jurisdictionTypeString = record["jurisdiction_type"] as? String,
            let jurisdictionType = JurisdictionType(rawValue: jurisdictionTypeString)
        {
            jurisdiction.jurisdictionType = jurisdictionType
        } else {
            jurisdiction.jurisdictionType = .state
        }
        try await jurisdiction.save(on: database)
    }

    // MARK: - EntityType

    public static func insertEntityType(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""

        let jurisdictionId: UUID?
        if let jurisdictionDict = record["jurisdiction"] as? [String: Any],
            let jurisdictionName = jurisdictionDict["name"] as? String
        {
            let jurisdiction = try await Jurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
            jurisdictionId = jurisdiction?.id
        } else if let jurisdictionIdString = record["jurisdiction_id"] as? String {
            jurisdictionId = UUID(uuidString: jurisdictionIdString)
        } else {
            jurisdictionId = nil
        }

        if !lookupFields.isEmpty,
            let jurisdictionId = jurisdictionId
        {
            if let existing = try await EntityType.query(on: database)
                .filter(\.$name == name)
                .filter(\.$jurisdiction.$id == jurisdictionId)
                .first()
            {
                try await existing.save(on: database)
                return
            }
        }

        let entityType = EntityType()
        entityType.name = name
        if let jurisdictionId = jurisdictionId {
            entityType.$jurisdiction.id = jurisdictionId
        }
        try await entityType.save(on: database)
    }

    // MARK: - Question

    public static func insertQuestion(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        if !lookupFields.isEmpty, let code = record["code"] as? String {
            if let existing = try await Question.query(on: database)
                .filter(\.$code == code)
                .first()
            {
                existing.prompt = record["prompt"] as? String ?? existing.prompt
                if let questionTypeString = record["question_type"] as? String,
                    let questionType = QuestionType(rawValue: questionTypeString)
                {
                    existing.questionType = questionType
                }
                existing.helpText = record["help_text"] as? String ?? existing.helpText
                existing.choices = record["choices"] as? [String: String] ?? existing.choices
                try await existing.save(on: database)
                return
            }
        }

        let question = Question()
        question.prompt = record["prompt"] as? String ?? ""
        if let questionTypeString = record["question_type"] as? String,
            let questionType = QuestionType(rawValue: questionTypeString)
        {
            question.questionType = questionType
        } else {
            question.questionType = .string
        }
        question.code = record["code"] as? String ?? ""
        question.helpText = record["help_text"] as? String ?? ""
        question.choices = record["choices"] as? [String: String]
        try await question.save(on: database)
    }

    // MARK: - Person

    public static func insertPerson(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        if !lookupFields.isEmpty, let email = record["email"] as? String {
            if let existing = try await Person.query(on: database)
                .filter(\.$email == email)
                .first()
            {
                existing.name = record["name"] as? String ?? existing.name
                try await existing.save(on: database)
                return
            }
        }

        let person = Person()
        person.name = record["name"] as? String ?? ""
        person.email = record["email"] as? String ?? ""
        try await person.save(on: database)
    }

    // MARK: - User

    public static func insertUser(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let personId: UUID?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
            personId = person?.id
        } else {
            personId = nil
        }

        guard let personId = personId else {
            return
        }

        if !lookupFields.isEmpty {
            if let existing = try await User.query(on: database)
                .filter(\.$person.$id == personId)
                .first()
            {
                if let roleString = record["role"] as? String,
                    let role = UserRole(rawValue: roleString)
                {
                    existing.role = role
                }
                try await existing.save(on: database)
                return
            }
        }

        let user = User()
        user.$person.id = personId
        if let roleString = record["role"] as? String,
            let role = UserRole(rawValue: roleString)
        {
            user.role = role
        } else {
            user.role = .client
        }
        try await user.save(on: database)
    }

    // MARK: - Entity

    public static func insertEntity(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""

        let entityTypeId: UUID?
        if let entityTypeDict = record["entity_type"] as? [String: Any],
            let entityTypeName = entityTypeDict["name"] as? String
        {
            if let jurisdictionDict = entityTypeDict["jurisdiction"] as? [String: Any],
                let jurisdictionName = jurisdictionDict["name"] as? String
            {
                let jurisdiction = try await Jurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()

                if let jurisdictionId = jurisdiction?.id {
                    let entityType = try await EntityType.query(on: database)
                        .filter(\.$name == entityTypeName)
                        .filter(\.$jurisdiction.$id == jurisdictionId)
                        .first()
                    entityTypeId = entityType?.id
                } else {
                    entityTypeId = nil
                }
            } else {
                let entityType = try await EntityType.query(on: database)
                    .filter(\.$name == entityTypeName)
                    .first()
                entityTypeId = entityType?.id
            }
        } else if let entityTypeIdString = record["legal_entity_type_id"] as? String {
            entityTypeId = UUID(uuidString: entityTypeIdString)
        } else {
            entityTypeId = nil
        }

        if !lookupFields.isEmpty, !name.isEmpty {
            if let existing = try await Entity.query(on: database)
                .filter(\.$name == name)
                .first()
            {
                if let entityTypeId = entityTypeId {
                    existing.$legalEntityType.id = entityTypeId
                }
                try await existing.save(on: database)
                return
            }
        }

        let entity = Entity()
        entity.name = name
        if let entityTypeId = entityTypeId {
            entity.$legalEntityType.id = entityTypeId
        }
        try await entity.save(on: database)
    }

    // MARK: - EntityBillingProfile

    public static func insertEntityBillingProfile(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let providerString = record["provider"] as? String ?? "xero"
        guard let provider = BillingProvider(rawValue: providerString) else { return }
        let externalContactId = record["external_contact_id"] as? String ?? ""

        let entityId: UUID?
        if let entityDict = record["entity"] as? [String: Any],
            let entityName = entityDict["name"] as? String
        {
            entityId = try await Entity.query(on: database)
                .filter(\.$name == entityName)
                .first()?.id
        } else if let entityIdString = record["entity_id"] as? String {
            entityId = UUID(uuidString: entityIdString)
        } else {
            entityId = nil
        }

        guard let entityId = entityId, !externalContactId.isEmpty else { return }

        if !lookupFields.isEmpty {
            if let existing = try await EntityBillingProfile.query(on: database)
                .filter(\.$provider == provider)
                .filter(\.$externalContactId == externalContactId)
                .first()
            {
                existing.$entity.id = entityId
                try await existing.save(on: database)
                return
            }
        }

        let profile = EntityBillingProfile()
        profile.$entity.id = entityId
        profile.provider = provider
        profile.externalContactId = externalContactId
        try await profile.save(on: database)
    }

    // MARK: - Invoice

    public static func insertInvoice(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let providerString = record["billing_profile_provider"] as? String ?? "xero"
        guard let provider = BillingProvider(rawValue: providerString) else { return }
        let billingExternalContactId = record["billing_profile_external_contact_id"] as? String ?? ""
        let externalInvoiceId = record["external_invoice_id"] as? String ?? ""

        guard !billingExternalContactId.isEmpty, !externalInvoiceId.isEmpty else { return }

        guard
            let profile = try await EntityBillingProfile.query(on: database)
                .filter(\.$provider == provider)
                .filter(\.$externalContactId == billingExternalContactId)
                .first(),
            let billingProfileId = profile.id
        else { return }

        guard let statusRaw = record["status"] as? String,
            let status = InvoiceStatus(rawValue: statusRaw)
        else { return }

        guard let invoiceTypeRaw = record["invoice_type"] as? String,
            let invoiceType = InvoiceType(rawValue: invoiceTypeRaw)
        else { return }

        let currencyCode = record["currency_code"] as? String ?? "USD"

        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withInternetDateTime]

        let calendarDateFormatter = DateFormatter()
        calendarDateFormatter.dateFormat = "yyyy-MM-dd"
        calendarDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        calendarDateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let invoiceDateString = record["invoice_date"] as? String,
            let invoiceDate = calendarDateFormatter.date(from: invoiceDateString)
        else { return }

        let dueDate: Date?
        if let dueString = record["due_date"] as? String {
            dueDate = calendarDateFormatter.date(from: dueString)
        } else {
            dueDate = nil
        }

        guard let externalUpdatedAtString = record["external_updated_at"] as? String,
            let externalUpdatedAt = isoDateFormatter.date(from: externalUpdatedAtString)
        else { return }

        let subTotal = decimalValue(record["sub_total"]) ?? 0
        let totalTax = decimalValue(record["total_tax"]) ?? 0
        let total = decimalValue(record["total"]) ?? 0
        let amountDue = decimalValue(record["amount_due"]) ?? 0
        let amountPaid = decimalValue(record["amount_paid"]) ?? 0
        let amountCredited = decimalValue(record["amount_credited"]) ?? 0

        if !lookupFields.isEmpty {
            if let existing = try await Invoice.query(on: database)
                .filter(\.$billingProfile.$id == billingProfileId)
                .filter(\.$externalInvoiceId == externalInvoiceId)
                .first()
            {
                existing.invoiceNumber = record["invoice_number"] as? String
                existing.reference = record["reference"] as? String
                existing.status = status
                existing.invoiceType = invoiceType
                existing.currencyCode = currencyCode
                existing.invoiceDate = invoiceDate
                existing.dueDate = dueDate
                existing.subTotal = subTotal
                existing.totalTax = totalTax
                existing.total = total
                existing.amountDue = amountDue
                existing.amountPaid = amountPaid
                existing.amountCredited = amountCredited
                existing.externalUpdatedAt = externalUpdatedAt
                existing.syncedAt = Date()
                try await existing.save(on: database)
                return
            }
        }

        let invoice = Invoice()
        invoice.$billingProfile.id = billingProfileId
        invoice.externalInvoiceId = externalInvoiceId
        invoice.invoiceNumber = record["invoice_number"] as? String
        invoice.reference = record["reference"] as? String
        invoice.status = status
        invoice.invoiceType = invoiceType
        invoice.currencyCode = currencyCode
        invoice.invoiceDate = invoiceDate
        invoice.dueDate = dueDate
        invoice.subTotal = subTotal
        invoice.totalTax = totalTax
        invoice.total = total
        invoice.amountDue = amountDue
        invoice.amountPaid = amountPaid
        invoice.amountCredited = amountCredited
        invoice.externalUpdatedAt = externalUpdatedAt
        invoice.syncedAt = Date()
        try await invoice.save(on: database)
    }

    // MARK: - InvoiceLineItem

    public static func insertInvoiceLineItem(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let providerString = record["billing_profile_provider"] as? String ?? "xero"
        guard let provider = BillingProvider(rawValue: providerString) else { return }
        let billingExternalContactId = record["billing_profile_external_contact_id"] as? String ?? ""
        let externalInvoiceId = record["external_invoice_id"] as? String ?? ""

        guard !billingExternalContactId.isEmpty, !externalInvoiceId.isEmpty else { return }

        guard
            let profile = try await EntityBillingProfile.query(on: database)
                .filter(\.$provider == provider)
                .filter(\.$externalContactId == billingExternalContactId)
                .first(),
            let billingProfileId = profile.id
        else { return }

        guard
            let invoice = try await Invoice.query(on: database)
                .filter(\.$billingProfile.$id == billingProfileId)
                .filter(\.$externalInvoiceId == externalInvoiceId)
                .first(),
            let invoiceId = invoice.id
        else { return }

        let lineNumberInt = record["line_number"] as? Int ?? 0
        let lineNumber = Int32(lineNumberInt)
        guard lineNumber > 0 else { return }

        let description = record["description"] as? String ?? ""
        guard !description.isEmpty else { return }

        let externalLineItemId = record["external_line_item_id"] as? String
        let itemCode = record["item_code"] as? String
        let accountCode = record["account_code"] as? String
        let taxType = record["tax_type"] as? String
        let quantity = decimalValue(record["quantity"]) ?? 0
        let unitAmount = decimalValue(record["unit_amount"]) ?? 0
        let taxAmount = decimalValue(record["tax_amount"]) ?? 0
        let lineAmount = decimalValue(record["line_amount"]) ?? 0
        let discountRate = decimalValue(record["discount_rate"])

        if !lookupFields.isEmpty {
            if let existing = try await InvoiceLineItem.query(on: database)
                .filter(\.$invoice.$id == invoiceId)
                .filter(\.$lineNumber == lineNumber)
                .first()
            {
                existing.externalLineItemId = externalLineItemId
                existing.description = description
                existing.itemCode = itemCode
                existing.accountCode = accountCode
                existing.quantity = quantity
                existing.unitAmount = unitAmount
                existing.taxType = taxType
                existing.taxAmount = taxAmount
                existing.lineAmount = lineAmount
                existing.discountRate = discountRate
                try await existing.save(on: database)
                return
            }
        }

        let lineItem = InvoiceLineItem()
        lineItem.$invoice.id = invoiceId
        lineItem.lineNumber = lineNumber
        lineItem.externalLineItemId = externalLineItemId
        lineItem.description = description
        lineItem.itemCode = itemCode
        lineItem.accountCode = accountCode
        lineItem.quantity = quantity
        lineItem.unitAmount = unitAmount
        lineItem.taxType = taxType
        lineItem.taxAmount = taxAmount
        lineItem.lineAmount = lineAmount
        lineItem.discountRate = discountRate
        try await lineItem.save(on: database)
    }

    private static func decimalValue(_ raw: Any?) -> Decimal? {
        if let decimal = raw as? Decimal {
            return decimal
        }
        if let string = raw as? String {
            return Decimal(string: string)
        }
        if let double = raw as? Double {
            return Decimal(double)
        }
        if let int = raw as? Int {
            return Decimal(int)
        }
        return nil
    }

    // MARK: - Credential

    public static func insertCredential(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let licenseNumber = record["license_number"] as? String ?? ""

        let personId: UUID?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
            personId = person?.id
        } else if let personIdString = record["person_id"] as? String {
            personId = UUID(uuidString: personIdString)
        } else {
            personId = nil
        }

        let jurisdictionId: UUID?
        if let jurisdictionDict = record["jurisdiction"] as? [String: Any],
            let jurisdictionName = jurisdictionDict["name"] as? String
        {
            let jurisdiction = try await Jurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
            jurisdictionId = jurisdiction?.id
        } else if let jurisdictionIdString = record["jurisdiction_id"] as? String {
            jurisdictionId = UUID(uuidString: jurisdictionIdString)
        } else {
            jurisdictionId = nil
        }

        if !lookupFields.isEmpty, !licenseNumber.isEmpty {
            if let existing = try await Credential.query(on: database)
                .filter(\.$licenseNumber == licenseNumber)
                .first()
            {
                if let personId = personId {
                    existing.$person.id = personId
                }
                if let jurisdictionId = jurisdictionId {
                    existing.$jurisdiction.id = jurisdictionId
                }
                try await existing.save(on: database)
                return
            }
        }

        let credential = Credential()
        credential.licenseNumber = licenseNumber
        if let personId = personId {
            credential.$person.id = personId
        }
        if let jurisdictionId = jurisdictionId {
            credential.$jurisdiction.id = jurisdictionId
        }
        try await credential.save(on: database)
    }

    // MARK: - Address

    public static func insertAddress(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let zip = record["zip"] as? String ?? ""
        let street = record["street"] as? String ?? ""

        if !lookupFields.isEmpty {
            var query = Address.query(on: database)

            if lookupFields.contains("zip") && !zip.isEmpty {
                query = query.filter(\.$zip == zip)
            }

            if lookupFields.contains("entity_id"),
                let entityId = try await resolveForeignKey("entity", from: record, database: database)
            {
                query = query.filter(\.$entity.$id == entityId)
            }

            if let existing = try await query.first() {
                if let entityId = try await resolveForeignKey("entity", from: record, database: database) {
                    existing.$entity.id = entityId
                }
                if let personId = try await resolveForeignKey("person", from: record, database: database) {
                    existing.$person.id = personId
                }
                if let mailroomDict = record["mailroom"] as? [String: Any],
                    let mailroomName = mailroomDict["name"] as? String,
                    let mailroom = try await Mailroom.query(on: database)
                        .filter(\.$name == mailroomName)
                        .first()
                {
                    existing.$mailroom.id = mailroom.id
                }
                try await existing.save(on: database)
                return
            }
        }

        let address = Address()
        address.street = street
        address.city = record["city"] as? String ?? ""
        address.state = record["state"] as? String
        address.zip = zip
        address.country = record["country"] as? String ?? "USA"
        address.isVerified = record["is_verified"] as? Bool ?? false

        if let entityId = try await resolveForeignKey("entity", from: record, database: database) {
            address.$entity.id = entityId
        }

        if let personId = try await resolveForeignKey("person", from: record, database: database) {
            address.$person.id = personId
        }

        if let mailroomDict = record["mailroom"] as? [String: Any],
            let mailroomName = mailroomDict["name"] as? String,
            let mailroom = try await Mailroom.query(on: database)
                .filter(\.$name == mailroomName)
                .first()
        {
            address.$mailroom.id = mailroom.id
        }

        try await address.save(on: database)
    }

    // MARK: - Mailroom

    public static func insertMailroom(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""

        if !lookupFields.isEmpty {
            if let existing = try await Mailroom.query(on: database)
                .filter(\.$name == name)
                .first()
            {
                existing.mailboxStart = record["mailbox_start"] as? Int ?? existing.mailboxStart
                existing.mailboxEnd = record["mailbox_end"] as? Int ?? existing.mailboxEnd
                existing.capacity = record["capacity"] as? Int ?? existing.capacity
                try await existing.save(on: database)
                return
            }
        }

        let mailroom = Mailroom()
        mailroom.name = name
        mailroom.mailboxStart = record["mailbox_start"] as? Int ?? 0
        mailroom.mailboxEnd = record["mailbox_end"] as? Int ?? 0
        mailroom.capacity = record["capacity"] as? Int
        try await mailroom.save(on: database)
    }

    // MARK: - PersonEntityRole

    public static func insertPersonEntityRole(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let personId: UUID?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
            personId = person?.id
        } else if let personIdString = record["person_id"] as? String {
            personId = UUID(uuidString: personIdString)
        } else {
            personId = nil
        }

        let entityId: UUID?
        if let entityDict = record["entity"] as? [String: Any],
            let entityName = entityDict["name"] as? String
        {
            let entity = try await Entity.query(on: database)
                .filter(\.$name == entityName)
                .first()
            entityId = entity?.id
        } else if let entityIdString = record["entity_id"] as? String {
            entityId = UUID(uuidString: entityIdString)
        } else {
            entityId = nil
        }

        let role = record["role"] as? String ?? "admin"

        if !lookupFields.isEmpty,
            let personId = personId,
            let entityId = entityId
        {
            let existing = try await PersonEntityRole.query(on: database)
                .filter(\.$person.$id == personId)
                .filter(\.$entity.$id == entityId)
                .filter(\.$role == PersonEntityRoleType(rawValue: role)!)
                .first()

            if existing != nil {
                return
            }
        }

        let personEntityRole = PersonEntityRole()
        if let personId = personId {
            personEntityRole.$person.id = personId
        }
        if let entityId = entityId {
            personEntityRole.$entity.id = entityId
        }
        if let roleType = PersonEntityRoleType(rawValue: role) {
            personEntityRole.role = roleType
        }
        try await personEntityRole.save(on: database)
    }

    // MARK: - PersonProjectRole

    public static func insertPersonProjectRole(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let personId: UUID?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            personId = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()?.id
        } else if let personIdString = record["person_id"] as? String {
            personId = UUID(uuidString: personIdString)
        } else {
            personId = nil
        }

        let projectId: UUID?
        if let projectDict = record["project"] as? [String: Any],
            let codename = projectDict["codename"] as? String
        {
            projectId = try await Project.query(on: database)
                .filter(\.$codename == codename)
                .first()?.id
        } else if let projectIdString = record["project_id"] as? String {
            projectId = UUID(uuidString: projectIdString)
        } else {
            projectId = nil
        }

        guard let personId = personId, let projectId = projectId else { return }

        let role = record["role"] as? String ?? "client"
        guard let roleType = ProjectRole(rawValue: role) else { return }

        if !lookupFields.isEmpty {
            let existing = try await PersonProjectRole.query(on: database)
                .filter(\.$person.$id == personId)
                .filter(\.$project.$id == projectId)
                .first()
            if existing != nil { return }
        }

        let personProjectRole = PersonProjectRole()
        personProjectRole.$person.id = personId
        personProjectRole.$project.id = projectId
        personProjectRole.role = roleType
        try await personProjectRole.save(on: database)
    }

    // MARK: - Answer

    public static func insertAnswer(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let questionCode = record["question_code"] as? String ?? ""
        let personEmail = record["person_email"] as? String ?? ""
        let value = record["value"] as? String ?? ""

        guard
            let question = try await Question.query(on: database)
                .filter(\.$code == questionCode)
                .first()
        else { return }

        guard
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
        else { return }

        guard let questionID = question.id, let personID = person.id else { return }

        let entityID: UUID?
        if let entityName = record["entity_name"] as? String {
            entityID = try await Entity.query(on: database)
                .filter(\.$name == entityName)
                .first()?.id
        } else {
            entityID = nil
        }

        let storedValue = JSONStored(value)

        if !lookupFields.isEmpty {
            var query = Answer.query(on: database)
                .filter(\.$question.$id == questionID)
                .filter(\.$person.$id == personID)
                .filter(\.$value == storedValue)
            if let eid = entityID {
                query = query.filter(\.$entity.$id == eid)
            }
            if try await query.first() != nil { return }
        }

        let answer = Answer()
        answer.$question.id = questionID
        answer.$person.id = personID
        answer.$entity.id = entityID
        answer.value = storedValue
        try await answer.save(on: database)
    }

    // MARK: - Sample Notations

    /// Seeds a `trusts__nevada` notation assigned to entity 1 (Shook Law LLC).
    ///
    /// Runs after templates are seeded so the `trusts__nevada` template is guaranteed
    /// to exist. Skips silently if the template or entity is missing, or if an active
    /// notation already exists for that template/entity combination.
    public static func seedSampleNotations(on database: Database, logger: Logger) async throws {
        let templateService = TemplateService(database: database)
        guard let template = try await templateService.findLatestByCode("trusts__nevada") else {
            logger.warning("trusts__nevada template not found, skipping sample notation seed")
            return
        }
        guard let templateID = template.id else { return }

        guard
            let entity = try await Entity.query(on: database)
                .filter(\.$name == "Shook Law LLC")
                .first(),
            let entityID = entity.id
        else {
            logger.warning("Shook Law LLC entity not found, skipping sample notation seed")
            return
        }

        let hasActive = try await Notation.hasActiveAssignment(
            templateID: templateID,
            personID: nil,
            entityID: entityID,
            on: database
        )
        guard !hasActive else {
            logger.debug("trusts__nevada notation already seeded, skipping")
            return
        }

        let notationService = NotationService(database: database)
        let notation = try await notationService.createNotation(
            templateID: templateID,
            personID: nil,
            entityID: entityID
        )
        let notationDescription = notation.id?.uuidString ?? "<unsaved>"
        logger.info("Seeded trusts__nevada notation \(notationDescription) for Shook Law LLC")
    }

    // MARK: - Foreign Key Resolution

    static func resolveForeignKey(
        _ key: String,
        from record: [String: Any],
        database: Database
    ) async throws -> UUID? {
        let directIdKey = "\(key)_id"

        if let directId = record[directIdKey] as? UUID {
            return directId
        }
        if let directIdString = record[directIdKey] as? String, let directId = UUID(uuidString: directIdString) {
            return directId
        }

        if let nestedData = record[key] as? [String: Any] {
            switch key {
            case "entity":
                return try await findOrCreateEntity(from: nestedData, database: database)
            case "person":
                if let email = nestedData["email"] as? String {
                    let person = try await Person.query(on: database)
                        .filter(\.$email == email)
                        .first()
                    return person?.id
                }
            case "jurisdiction":
                if let name = nestedData["name"] as? String {
                    let jurisdiction = try await Jurisdiction.query(on: database)
                        .filter(\.$name == name)
                        .first()
                    return jurisdiction?.id
                }
            case "address":
                return try await findOrCreateAddress(from: nestedData, database: database)
            default:
                break
            }
        }

        return nil
    }

    static func findOrCreateEntity(
        from entityData: [String: Any],
        database: Database
    ) async throws -> UUID? {
        let name = entityData["name"] as? String ?? ""

        if let existing = try await Entity.query(on: database)
            .filter(\.$name == name)
            .first()
        {
            return existing.id
        }

        let entity = Entity()
        entity.name = name

        if let entityTypeData = entityData["entity_type"] as? [String: Any],
            let entityTypeName = entityTypeData["name"] as? String
        {

            if let jurisdictionData = entityTypeData["jurisdiction"] as? [String: Any],
                let jurisdictionName = jurisdictionData["name"] as? String
            {

                let jurisdiction = try await Jurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()

                if let jurisdictionId = jurisdiction?.id {
                    let entityType = try await EntityType.query(on: database)
                        .filter(\.$name == entityTypeName)
                        .filter(\.$jurisdiction.$id == jurisdictionId)
                        .first()

                    if let entityTypeId = entityType?.id {
                        entity.$legalEntityType.id = entityTypeId
                    }
                }
            }
        }

        try await entity.save(on: database)
        return entity.id
    }

    static func findOrCreateAddress(
        from addressData: [String: Any],
        database: Database
    ) async throws -> UUID? {
        let zip = addressData["zip"] as? String ?? ""
        let street = addressData["street"] as? String ?? ""

        if let existing = try await Address.query(on: database)
            .filter(\.$zip == zip)
            .filter(\.$street == street)
            .first()
        {
            return existing.id
        }

        let address = Address()
        address.street = street
        address.city = addressData["city"] as? String ?? ""
        address.state = addressData["state"] as? String
        address.zip = zip
        address.country = addressData["country"] as? String ?? "USA"
        address.isVerified = addressData["is_verified"] as? Bool ?? false

        if let entityId = try await resolveForeignKey("entity", from: addressData, database: database) {
            address.$entity.id = entityId
        }

        if let personId = try await resolveForeignKey("person", from: addressData, database: database) {
            address.$person.id = personId
        }

        try await address.save(on: database)
        return address.id
    }
}

// MARK: - Private Types

private struct ExampleTemplateYAML: Decodable {
    let title: String?
    let description: String?
    let respondentType: String?
    let questionnaire: [String: [String: String]]?
    let workflow: [String: [String: String]]?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case respondentType = "respondent_type"
        case questionnaire
        case workflow
    }
}

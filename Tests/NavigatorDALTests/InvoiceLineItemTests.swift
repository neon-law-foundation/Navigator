import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import SQLKit
import Testing
import Vapor

@Suite("InvoiceLineItem Database Operations")
struct InvoiceLineItemTests {

    @Test("Repository create + read round-trips every field, including Decimal money columns")
    func testCreateAndFind() async throws {
        try await withDatabase { db in
            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            let lineItem = InvoiceLineItem()
            lineItem.$invoice.id = invoiceId
            lineItem.lineNumber = 1
            lineItem.externalLineItemId = "line-ext-1"
            lineItem.description = "Legal services"
            lineItem.itemCode = "RETAINER"
            lineItem.accountCode = "200"
            lineItem.quantity = Decimal(string: "10.0000")!
            lineItem.unitAmount = Decimal(string: "75.0000")!
            lineItem.taxType = "OUTPUT"
            lineItem.taxAmount = Decimal(string: "0.0000")!
            lineItem.lineAmount = Decimal(string: "750.0000")!
            lineItem.discountRate = Decimal(string: "5.0000")!

            let created = try await repo.create(model: lineItem)
            #expect(created.id != nil)

            let reloaded = try #require(try await repo.find(id: created.id!))
            #expect(reloaded.$invoice.id == invoiceId)
            #expect(reloaded.lineNumber == 1)
            #expect(reloaded.externalLineItemId == "line-ext-1")
            #expect(reloaded.description == "Legal services")
            #expect(reloaded.itemCode == "RETAINER")
            #expect(reloaded.accountCode == "200")
            #expect(reloaded.quantity == Decimal(string: "10.0000"))
            #expect(reloaded.unitAmount == Decimal(string: "75.0000"))
            #expect(reloaded.taxType == "OUTPUT")
            #expect(reloaded.taxAmount == Decimal(string: "0.0000"))
            #expect(reloaded.lineAmount == Decimal(string: "750.0000"))
            #expect(reloaded.discountRate == Decimal(string: "5.0000"))
        }
    }

    @Test("Deleting the parent invoice cascades to its line items")
    func testCascadeOnInvoiceDelete() async throws {
        try await withDatabase { db in
            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            let lineItem = InvoiceLineItem()
            lineItem.$invoice.id = invoiceId
            lineItem.lineNumber = 1
            lineItem.description = "Service A"
            lineItem.quantity = Decimal(string: "1.0000")!
            lineItem.unitAmount = Decimal(string: "100.0000")!
            lineItem.taxAmount = Decimal(string: "0.0000")!
            lineItem.lineAmount = Decimal(string: "100.0000")!
            _ = try await repo.create(model: lineItem)

            let beforeDelete = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(beforeDelete.count == 1)

            // Cascade delete the parent invoice
            let invoice = try #require(try await Invoice.find(invoiceId, on: db))
            try await invoice.delete(on: db)

            let afterDelete = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(afterDelete.isEmpty, "ON DELETE CASCADE should remove line items")
        }
    }

    @Test("replaceAll inserts every payload row in order when no existing rows")
    func testReplaceAllOnEmpty() async throws {
        try await withDatabase { db in
            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            let payloads: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 1, description: "First"),
                makePayload(lineNumber: 2, description: "Second"),
                makePayload(lineNumber: 3, description: "Third"),
            ]

            try await repo.replaceAll(forInvoiceId: invoiceId, with: payloads)

            let rows = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(rows.count == 3)
            #expect(rows[0].lineNumber == 1)
            #expect(rows[0].description == "First")
            #expect(rows[1].lineNumber == 2)
            #expect(rows[1].description == "Second")
            #expect(rows[2].lineNumber == 3)
            #expect(rows[2].description == "Third")
        }
    }

    @Test("replaceAll deletes the existing set entirely before inserting the new payloads")
    func testReplaceAllDeletesExistingSentinel() async throws {
        try await withDatabase { db in
            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            // Insert a sentinel row that the replacement payload does NOT include.
            let sentinel = InvoiceLineItem()
            sentinel.$invoice.id = invoiceId
            sentinel.lineNumber = 99
            sentinel.description = "SENTINEL - should be deleted by replaceAll"
            sentinel.quantity = Decimal(string: "1.0000")!
            sentinel.unitAmount = Decimal(string: "1.0000")!
            sentinel.taxAmount = Decimal(string: "0.0000")!
            sentinel.lineAmount = Decimal(string: "1.0000")!
            try await sentinel.save(on: db)

            let payloads: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 1, description: "Replacement A"),
                makePayload(lineNumber: 2, description: "Replacement B"),
            ]
            try await repo.replaceAll(forInvoiceId: invoiceId, with: payloads)

            let rows = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(rows.count == 2)
            #expect(
                !rows.contains(where: { $0.description.hasPrefix("SENTINEL") }),
                "Sentinel row's description must not survive the replacement"
            )
            #expect(
                !rows.contains(where: { $0.lineNumber == 99 }),
                "Sentinel row's line_number must not survive the replacement"
            )
        }
    }

    @Test("replaceAll with empty array deletes every existing row for the invoice")
    func testReplaceAllEmptyArray() async throws {
        try await withDatabase { db in
            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            try await repo.replaceAll(
                forInvoiceId: invoiceId,
                with: [
                    makePayload(lineNumber: 1, description: "doomed-1"),
                    makePayload(lineNumber: 2, description: "doomed-2"),
                ]
            )
            #expect(try await repo.findForInvoice(invoiceId: invoiceId).count == 2)

            try await repo.replaceAll(forInvoiceId: invoiceId, with: [])

            let rows = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(rows.isEmpty, "Empty payload should leave no rows")
        }
    }

    @Test(
        "replaceAll never merges by external_line_item_id: matching rows are deleted-and-reinserted"
    )
    func testReplaceAllRejectsMergeByExternalId() async throws {
        try await withDatabase { db in
            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            // Pre-existing row with external_line_item_id "X" and a known description.
            let original = InvoiceLineItem()
            original.$invoice.id = invoiceId
            original.lineNumber = 1
            original.externalLineItemId = "X"
            original.description = "Original description"
            original.quantity = Decimal(string: "1.0000")!
            original.unitAmount = Decimal(string: "100.0000")!
            original.taxAmount = Decimal(string: "0.0000")!
            original.lineAmount = Decimal(string: "100.0000")!
            try await original.save(on: db)
            let originalInsertedAt = try #require(original.insertedAt)

            // Force a measurable wall-clock gap so the new row's insertedAt
            // strictly exceeds the original's.
            try await Task.sleep(nanoseconds: 50_000_000)

            // Replace with a single payload that ALSO has external_line_item_id "X"
            // but a DIFFERENT description. If the repository merged by external id
            // (i.e. updated the existing row in place), the row's `insertedAt`
            // would be preserved. It must not be — the row was deleted and a
            // new row was inserted, so `insertedAt` advances.
            let replacement = InvoiceLineItemPayload(
                lineNumber: 1,
                externalLineItemId: "X",
                description: "Different description",
                itemCode: nil,
                accountCode: nil,
                quantity: Decimal(string: "1.0000")!,
                unitAmount: Decimal(string: "200.0000")!,
                taxType: nil,
                taxAmount: Decimal(string: "0.0000")!,
                lineAmount: Decimal(string: "200.0000")!,
                discountRate: nil
            )
            try await repo.replaceAll(forInvoiceId: invoiceId, with: [replacement])

            let rows = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(rows.count == 1)
            let only = try #require(rows.first)
            #expect(only.externalLineItemId == "X")
            #expect(only.description == "Different description")
            #expect(only.unitAmount == Decimal(string: "200.0000"))
            let newInsertedAt = try #require(only.insertedAt)
            #expect(
                newInsertedAt > originalInsertedAt,
                """
                Merging is forbidden by design: the row must be deleted and \
                reinserted, so its insertedAt must strictly exceed the \
                original's. Equal insertedAt would mean the row was updated \
                in place, which is not allowed.
                """
            )
        }
    }

    @Test("replaceAll is transactional: a mid-transaction failure leaves original rows intact")
    func testReplaceAllTransactionRollback() async throws {
        try await withDatabase { db in
            // The Postgres NUMERIC(19,4) constraint can be violated by a value
            // outside its scale; SQLite's NUMERIC affinity is lenient and won't
            // reject the same value, so this test only runs on Postgres.
            guard let sql = db as? SQLDatabase else { return }
            guard sql.dialect.name == "postgresql" else { return }

            let invoiceId = try await makeInvoice(on: db)
            let repo = InvoiceLineItemRepository(database: db)

            let original = InvoiceLineItem()
            original.$invoice.id = invoiceId
            original.lineNumber = 1
            original.description = "Original survivor"
            original.quantity = Decimal(string: "1.0000")!
            original.unitAmount = Decimal(string: "1.0000")!
            original.taxAmount = Decimal(string: "0.0000")!
            original.lineAmount = Decimal(string: "1.0000")!
            try await original.save(on: db)

            // Construct a payload whose second row has a `quantity` that
            // overflows NUMERIC(19,4) (precision 19). The first insert succeeds,
            // the second fails, the whole transaction rolls back.
            let overflow = Decimal(string: "1234567890123456.0000")!  // 16 digits — fits
            let truncating = Decimal(string: "12345678901234567890.0000")!  // 20 digits — overflows precision 19
            let payloads: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 10, description: "OK row", quantity: overflow),
                makePayload(lineNumber: 11, description: "Overflow row", quantity: truncating),
            ]

            await #expect(throws: (any Error).self) {
                try await repo.replaceAll(forInvoiceId: invoiceId, with: payloads)
            }

            let rows = try await repo.findForInvoice(invoiceId: invoiceId)
            #expect(rows.count == 1, "Original row must survive a rolled-back transaction")
            #expect(rows.first?.description == "Original survivor")
        }
    }

    @Test("upsertWithLineItems inserts header and replaces line items end-to-end")
    func testUpsertWithLineItemsInsert() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let invoiceRepo = InvoiceRepository(database: db)
            let lineRepo = InvoiceLineItemRepository(database: db)

            let initialPayload = makeInvoicePayload(
                externalUpdatedAt: isoDate("2026-04-01T12:00:00Z")
            )
            let initialLines: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 1, description: "Line A"),
                makePayload(lineNumber: 2, description: "Line B"),
                makePayload(lineNumber: 3, description: "Line C"),
            ]

            let firstOutcome = try await invoiceRepo.upsertWithLineItems(
                externalInvoiceId: "ext-with-lines",
                billingProfileId: billingProfileId,
                invoicePayload: initialPayload,
                lineItems: initialLines
            )
            guard case .inserted(let invoiceId) = firstOutcome else {
                Issue.record("Expected .inserted, got \(firstOutcome)")
                return
            }
            #expect(try await lineRepo.findForInvoice(invoiceId: invoiceId).count == 3)

            // Re-sync with advanced external_updated_at and a SHORTER list.
            var advancedPayload = initialPayload
            advancedPayload.externalUpdatedAt = isoDate("2026-04-02T12:00:00Z")
            advancedPayload.status = .paid
            let updatedLines: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 1, description: "Line A revised"),
                makePayload(lineNumber: 2, description: "Line B revised"),
            ]

            let secondOutcome = try await invoiceRepo.upsertWithLineItems(
                externalInvoiceId: "ext-with-lines",
                billingProfileId: billingProfileId,
                invoicePayload: advancedPayload,
                lineItems: updatedLines
            )
            guard case .updated(let updatedInvoiceId) = secondOutcome else {
                Issue.record("Expected .updated, got \(secondOutcome)")
                return
            }
            #expect(updatedInvoiceId == invoiceId)

            let header = try #require(try await invoiceRepo.find(id: invoiceId))
            #expect(header.status == .paid)

            let rows = try await lineRepo.findForInvoice(invoiceId: invoiceId)
            #expect(rows.count == 2, "No leftover third row should remain")
            #expect(rows.map(\.description) == ["Line A revised", "Line B revised"])
        }
    }

    @Test("upsertWithLineItems leaves existing line items untouched on .skippedUnchanged")
    func testUpsertWithLineItemsSkippedLeavesLinesAlone() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let invoiceRepo = InvoiceRepository(database: db)
            let lineRepo = InvoiceLineItemRepository(database: db)

            let payload = makeInvoicePayload(
                externalUpdatedAt: isoDate("2026-04-01T12:00:00Z")
            )
            let originalLines: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 1, description: "Original X"),
                makePayload(lineNumber: 2, description: "Original Y"),
            ]
            let inserted = try await invoiceRepo.upsertWithLineItems(
                externalInvoiceId: "ext-skip",
                billingProfileId: billingProfileId,
                invoicePayload: payload,
                lineItems: originalLines
            )
            guard case .inserted(let invoiceId) = inserted else {
                Issue.record("Expected .inserted, got \(inserted)")
                return
            }
            let originalRows = try await lineRepo.findForInvoice(invoiceId: invoiceId)
            #expect(originalRows.count == 2)
            let originalIds = originalRows.compactMap(\.id)

            // Re-sync with the SAME external_updated_at — header skips work, lines
            // must also be left alone.
            let bogusReplacementLines: [InvoiceLineItemPayload] = [
                makePayload(lineNumber: 1, description: "Should NOT be applied")
            ]
            let secondOutcome = try await invoiceRepo.upsertWithLineItems(
                externalInvoiceId: "ext-skip",
                billingProfileId: billingProfileId,
                invoicePayload: payload,
                lineItems: bogusReplacementLines
            )
            guard case .skippedUnchanged = secondOutcome else {
                Issue.record("Expected .skippedUnchanged, got \(secondOutcome)")
                return
            }

            let after = try await lineRepo.findForInvoice(invoiceId: invoiceId)
            #expect(after.count == 2, "Skipped header must not touch line items")
            #expect(after.map(\.description) == ["Original X", "Original Y"])
            #expect(after.compactMap(\.id) == originalIds, "Primary keys must be preserved")
        }
    }

    // MARK: - Helpers

    private func makeBillingProfile(on db: Database) async throws -> UUID {
        let jurisdiction = Jurisdiction()
        jurisdiction.code = "NV-\(UUID().uuidString.prefix(8))"
        jurisdiction.name = "Jurisdiction-\(UUID().uuidString.prefix(8))"
        jurisdiction.jurisdictionType = .state
        try await jurisdiction.save(on: db)

        let entityType = EntityType()
        entityType.name = "LLC-\(UUID().uuidString.prefix(8))"
        entityType.$jurisdiction.id = jurisdiction.id!
        try await entityType.save(on: db)

        let entity = Entity()
        entity.name = "Line Item Test Entity \(UUID().uuidString.prefix(8))"
        entity.$legalEntityType.id = entityType.id!
        try await entity.save(on: db)

        let profile = EntityBillingProfile()
        profile.$entity.id = entity.id!
        profile.provider = .xero
        profile.externalContactId = "contact-\(UUID().uuidString)"
        try await profile.save(on: db)

        return profile.id!
    }

    private func makeInvoice(on db: Database) async throws -> UUID {
        let billingProfileId = try await makeBillingProfile(on: db)
        let invoice = Invoice()
        invoice.$billingProfile.id = billingProfileId
        invoice.externalInvoiceId = "inv-\(UUID().uuidString)"
        invoice.invoiceNumber = "INV-XXXX"
        invoice.reference = nil
        invoice.status = .authorised
        invoice.invoiceType = .accrec
        invoice.currencyCode = "USD"
        invoice.invoiceDate = date("2026-04-01")
        invoice.dueDate = date("2026-05-01")
        invoice.subTotal = Decimal(string: "1000.0000")!
        invoice.totalTax = Decimal(string: "0.0000")!
        invoice.total = Decimal(string: "1000.0000")!
        invoice.amountDue = Decimal(string: "1000.0000")!
        invoice.amountPaid = Decimal(string: "0.0000")!
        invoice.amountCredited = Decimal(string: "0.0000")!
        invoice.externalUpdatedAt = isoDate("2026-04-01T12:00:00Z")
        invoice.syncedAt = isoDate("2026-04-01T12:00:00Z")
        try await invoice.save(on: db)
        return invoice.id!
    }

    private func makePayload(
        lineNumber: Int32,
        description: String,
        quantity: Decimal? = nil
    ) -> InvoiceLineItemPayload {
        InvoiceLineItemPayload(
            lineNumber: lineNumber,
            externalLineItemId: "ext-line-\(lineNumber)",
            description: description,
            itemCode: nil,
            accountCode: nil,
            quantity: quantity ?? Decimal(string: "1.0000")!,
            unitAmount: Decimal(string: "100.0000")!,
            taxType: nil,
            taxAmount: Decimal(string: "0.0000")!,
            lineAmount: Decimal(string: "100.0000")!,
            discountRate: nil
        )
    }

    private func makeInvoicePayload(externalUpdatedAt: Date) -> InvoiceUpsertPayload {
        InvoiceUpsertPayload(
            invoiceNumber: "INV-0001",
            reference: "Initial",
            status: .authorised,
            invoiceType: .accrec,
            currencyCode: "USD",
            invoiceDate: date("2026-04-01"),
            dueDate: date("2026-05-01"),
            subTotal: Decimal(string: "1000.0000")!,
            totalTax: Decimal(string: "0.0000")!,
            total: Decimal(string: "1000.0000")!,
            amountDue: Decimal(string: "1000.0000")!,
            amountPaid: Decimal(string: "0.0000")!,
            amountCredited: Decimal(string: "0.0000")!,
            pdfBlobId: nil,
            externalUpdatedAt: externalUpdatedAt
        )
    }

    private func date(_ string: String) -> Date {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: string)!
    }

    private func isoDate(_ string: String) -> Date {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: string)!
    }
}

import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import SQLKit
import Testing
import Vapor

@Suite("Invoice Database Operations")
struct InvoiceTests {

    @Test("Repository create + read round-trips every field, including Decimal money columns")
    func testCreateAndFind() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let repo = InvoiceRepository(database: db)

            let invoice = Invoice()
            invoice.$billingProfile.id = billingProfileId
            invoice.externalInvoiceId = "ext-roundtrip"
            invoice.invoiceNumber = "INV-0001"
            invoice.reference = "Roundtrip"
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

            let created = try await repo.create(model: invoice)
            #expect(created.id != nil)

            let reloaded = try #require(try await repo.find(id: created.id!))
            #expect(reloaded.$billingProfile.id == billingProfileId)
            #expect(reloaded.externalInvoiceId == "ext-roundtrip")
            #expect(reloaded.invoiceNumber == "INV-0001")
            #expect(reloaded.reference == "Roundtrip")
            #expect(reloaded.status == .authorised)
            #expect(reloaded.invoiceType == .accrec)
            #expect(reloaded.currencyCode == "USD")
            #expect(reloaded.subTotal == Decimal(string: "1000.0000"))
            #expect(reloaded.total == Decimal(string: "1000.0000"))
            #expect(reloaded.amountDue == Decimal(string: "1000.0000"))
            #expect(reloaded.amountPaid == Decimal(string: "0.0000"))
            #expect(reloaded.amountCredited == Decimal(string: "0.0000"))
            #expect(reloaded.$pdfBlob.id == nil)
        }
    }

    @Test("UNIQUE (billing_profile_id, external_invoice_id) rejects duplicates")
    func testUniqueBillingProfileExternalInvoiceId() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let repo = InvoiceRepository(database: db)

            let first = makeInvoice(
                billingProfileId: billingProfileId,
                externalInvoiceId: "dup-invoice-id"
            )
            _ = try await repo.create(model: first)

            let duplicate = makeInvoice(
                billingProfileId: billingProfileId,
                externalInvoiceId: "dup-invoice-id"
            )

            await #expect(throws: (any Error).self) {
                _ = try await repo.create(model: duplicate)
            }
        }
    }

    @Test("upsert inserts a new invoice when no row exists")
    func testUpsertInserts() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let repo = InvoiceRepository(database: db)

            let payload = makePayload(
                externalUpdatedAt: isoDate("2026-04-01T12:00:00Z")
            )

            let outcome = try await repo.upsert(
                externalInvoiceId: "ext-insert",
                billingProfileId: billingProfileId,
                payload: payload
            )

            guard case .inserted(let invoiceId) = outcome else {
                Issue.record("Expected .inserted, got \(outcome)")
                return
            }

            let reloaded = try #require(try await repo.find(id: invoiceId))
            #expect(reloaded.externalInvoiceId == "ext-insert")
            #expect(reloaded.status == .authorised)
            #expect(reloaded.invoiceType == .accrec)
            #expect(reloaded.currencyCode == "USD")
            #expect(reloaded.subTotal == Decimal(string: "1000.0000"))
            #expect(reloaded.total == Decimal(string: "1000.0000"))
            #expect(reloaded.amountDue == Decimal(string: "1000.0000"))
            #expect(reloaded.externalUpdatedAt == isoDate("2026-04-01T12:00:00Z"))
        }
    }

    @Test("upsert with a later external_updated_at overwrites business fields and advances timestamps")
    func testUpsertUpdates() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let repo = InvoiceRepository(database: db)

            let initialPayload = makePayload(
                externalUpdatedAt: isoDate("2026-04-01T12:00:00Z")
            )
            let insertOutcome = try await repo.upsert(
                externalInvoiceId: "ext-update",
                billingProfileId: billingProfileId,
                payload: initialPayload
            )
            guard case .inserted(let invoiceId) = insertOutcome else {
                Issue.record("Expected initial .inserted, got \(insertOutcome)")
                return
            }
            let beforeUpdate = try #require(try await repo.find(id: invoiceId))
            let syncedAtBefore = beforeUpdate.syncedAt

            // Force a visible wall-clock gap so the new syncedAt must differ.
            try await Task.sleep(nanoseconds: 10_000_000)

            var secondPayload = initialPayload
            secondPayload.status = .paid
            secondPayload.amountDue = Decimal(string: "0.0000")!
            secondPayload.amountPaid = Decimal(string: "1000.0000")!
            secondPayload.externalUpdatedAt = isoDate("2026-04-02T12:00:00Z")

            let updateOutcome = try await repo.upsert(
                externalInvoiceId: "ext-update",
                billingProfileId: billingProfileId,
                payload: secondPayload
            )
            guard case .updated(let updatedId) = updateOutcome else {
                Issue.record("Expected .updated, got \(updateOutcome)")
                return
            }
            #expect(updatedId == invoiceId)

            let afterUpdate = try #require(try await repo.find(id: invoiceId))
            #expect(afterUpdate.status == .paid)
            #expect(afterUpdate.amountDue == Decimal(string: "0.0000"))
            #expect(afterUpdate.amountPaid == Decimal(string: "1000.0000"))
            #expect(afterUpdate.externalUpdatedAt == isoDate("2026-04-02T12:00:00Z"))
            #expect(afterUpdate.syncedAt > syncedAtBefore)
        }
    }

    @Test("upsert with an equal external_updated_at skips business fields but advances synced_at")
    func testUpsertSkipsEqual() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let repo = InvoiceRepository(database: db)

            let payload = makePayload(
                externalUpdatedAt: isoDate("2026-04-01T12:00:00Z")
            )
            let insertOutcome = try await repo.upsert(
                externalInvoiceId: "ext-skip-equal",
                billingProfileId: billingProfileId,
                payload: payload
            )
            guard case .inserted(let invoiceId) = insertOutcome else {
                Issue.record("Expected .inserted, got \(insertOutcome)")
                return
            }
            let before = try #require(try await repo.find(id: invoiceId))
            let statusBefore = before.status
            let amountDueBefore = before.amountDue
            let syncedAtBefore = before.syncedAt

            try await Task.sleep(nanoseconds: 10_000_000)

            var tamperedPayload = payload
            tamperedPayload.status = .paid
            tamperedPayload.amountDue = Decimal(string: "0.0000")!

            let outcome = try await repo.upsert(
                externalInvoiceId: "ext-skip-equal",
                billingProfileId: billingProfileId,
                payload: tamperedPayload
            )
            guard case .skippedUnchanged(let skippedId) = outcome else {
                Issue.record("Expected .skippedUnchanged, got \(outcome)")
                return
            }
            #expect(skippedId == invoiceId)

            let after = try #require(try await repo.find(id: invoiceId))
            #expect(after.status == statusBefore)
            #expect(after.amountDue == amountDueBefore)
            #expect(after.externalUpdatedAt == isoDate("2026-04-01T12:00:00Z"))
            #expect(after.syncedAt > syncedAtBefore)
        }
    }

    @Test("upsert with an earlier external_updated_at skips business fields but advances synced_at")
    func testUpsertSkipsEarlier() async throws {
        try await withDatabase { db in
            let billingProfileId = try await makeBillingProfile(on: db)
            let repo = InvoiceRepository(database: db)

            let payload = makePayload(
                externalUpdatedAt: isoDate("2026-04-05T12:00:00Z")
            )
            let insertOutcome = try await repo.upsert(
                externalInvoiceId: "ext-skip-earlier",
                billingProfileId: billingProfileId,
                payload: payload
            )
            guard case .inserted(let invoiceId) = insertOutcome else {
                Issue.record("Expected .inserted, got \(insertOutcome)")
                return
            }
            let before = try #require(try await repo.find(id: invoiceId))
            let syncedAtBefore = before.syncedAt
            let statusBefore = before.status

            try await Task.sleep(nanoseconds: 10_000_000)

            var stalePayload = payload
            stalePayload.status = .voided
            stalePayload.externalUpdatedAt = isoDate("2026-04-01T00:00:00Z")

            let outcome = try await repo.upsert(
                externalInvoiceId: "ext-skip-earlier",
                billingProfileId: billingProfileId,
                payload: stalePayload
            )
            guard case .skippedUnchanged = outcome else {
                Issue.record("Expected .skippedUnchanged, got \(outcome)")
                return
            }

            let after = try #require(try await repo.find(id: invoiceId))
            #expect(after.status == statusBefore)
            #expect(after.externalUpdatedAt == isoDate("2026-04-05T12:00:00Z"))
            #expect(after.syncedAt > syncedAtBefore)
        }
    }

    @Test("status CHECK constraint rejects unknown values on Postgres")
    func testStatusCheckConstraint() async throws {
        try await withDatabase { db in
            guard let sql = db as? SQLDatabase else { return }
            guard sql.dialect.name == "postgresql" else { return }

            let billingProfileId = try await makeBillingProfile(on: db)

            await #expect(throws: (any Error).self) {
                try await sql.raw(
                    """
                    INSERT INTO invoices (
                        billing_profile_id, external_invoice_id, status, invoice_type,
                        currency_code, invoice_date,
                        sub_total, total_tax, total, amount_due, amount_paid, amount_credited,
                        external_updated_at, synced_at, inserted_at, updated_at
                    ) VALUES (
                        \(bind: billingProfileId), 'ext-bad-status', 'nonsense', 'accrec',
                        'USD', CURRENT_DATE,
                        0, 0, 0, 0, 0, 0,
                        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                    )
                    """
                ).run()
            }
        }
    }

    @Test("invoice_type CHECK constraint rejects unknown values on Postgres")
    func testInvoiceTypeCheckConstraint() async throws {
        try await withDatabase { db in
            guard let sql = db as? SQLDatabase else { return }
            guard sql.dialect.name == "postgresql" else { return }

            let billingProfileId = try await makeBillingProfile(on: db)

            await #expect(throws: (any Error).self) {
                try await sql.raw(
                    """
                    INSERT INTO invoices (
                        billing_profile_id, external_invoice_id, status, invoice_type,
                        currency_code, invoice_date,
                        sub_total, total_tax, total, amount_due, amount_paid, amount_credited,
                        external_updated_at, synced_at, inserted_at, updated_at
                    ) VALUES (
                        \(bind: billingProfileId), 'ext-bad-type', 'authorised', 'bogus',
                        'USD', CURRENT_DATE,
                        0, 0, 0, 0, 0, 0,
                        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                    )
                    """
                ).run()
            }
        }
    }

    @Test("currency_code CHECK constraint rejects non-3-character values on Postgres")
    func testCurrencyCodeCheckConstraint() async throws {
        try await withDatabase { db in
            guard let sql = db as? SQLDatabase else { return }
            guard sql.dialect.name == "postgresql" else { return }

            let billingProfileId = try await makeBillingProfile(on: db)

            await #expect(throws: (any Error).self) {
                try await sql.raw(
                    """
                    INSERT INTO invoices (
                        billing_profile_id, external_invoice_id, status, invoice_type,
                        currency_code, invoice_date,
                        sub_total, total_tax, total, amount_due, amount_paid, amount_credited,
                        external_updated_at, synced_at, inserted_at, updated_at
                    ) VALUES (
                        \(bind: billingProfileId), 'ext-bad-currency', 'authorised', 'accrec',
                        'USDX', CURRENT_DATE,
                        0, 0, 0, 0, 0, 0,
                        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                    )
                    """
                ).run()
            }
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
        entity.name = "Invoice Test Entity \(UUID().uuidString.prefix(8))"
        entity.$legalEntityType.id = entityType.id!
        try await entity.save(on: db)

        let profile = EntityBillingProfile()
        profile.$entity.id = entity.id!
        profile.provider = .xero
        profile.externalContactId = "contact-\(UUID().uuidString)"
        try await profile.save(on: db)

        return profile.id!
    }

    private func makeInvoice(
        billingProfileId: UUID,
        externalInvoiceId: String
    ) -> Invoice {
        let invoice = Invoice()
        invoice.$billingProfile.id = billingProfileId
        invoice.externalInvoiceId = externalInvoiceId
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
        return invoice
    }

    private func makePayload(externalUpdatedAt: Date) -> InvoiceUpsertPayload {
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

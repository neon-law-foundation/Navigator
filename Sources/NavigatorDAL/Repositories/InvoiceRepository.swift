import FluentKit
import Foundation

/// Business-field payload for
/// ``InvoiceRepository/upsert(externalInvoiceId:billingProfileId:payload:)``.
///
/// Carries everything about a provider invoice *except* the idempotency key
/// (`externalInvoiceId`, `billingProfileId`) — those are passed separately
/// so the upsert surface reads like a keyed write rather than a free-form
/// patch. `externalUpdatedAt` is part of the payload because it drives the
/// skip-work comparison; `syncedAt` is *not* part of the payload because
/// it is stamped by the repository on every call.
public struct InvoiceUpsertPayload: Sendable {
    public var invoiceNumber: String?
    public var reference: String?
    public var status: InvoiceStatus
    public var invoiceType: InvoiceType
    public var currencyCode: String
    public var invoiceDate: Date
    public var dueDate: Date?
    public var subTotal: Decimal
    public var totalTax: Decimal
    public var total: Decimal
    public var amountDue: Decimal
    public var amountPaid: Decimal
    public var amountCredited: Decimal
    public var pdfBlobId: UUID?
    public var externalUpdatedAt: Date

    public init(
        invoiceNumber: String?,
        reference: String?,
        status: InvoiceStatus,
        invoiceType: InvoiceType,
        currencyCode: String,
        invoiceDate: Date,
        dueDate: Date?,
        subTotal: Decimal,
        totalTax: Decimal,
        total: Decimal,
        amountDue: Decimal,
        amountPaid: Decimal,
        amountCredited: Decimal,
        pdfBlobId: UUID?,
        externalUpdatedAt: Date
    ) {
        self.invoiceNumber = invoiceNumber
        self.reference = reference
        self.status = status
        self.invoiceType = invoiceType
        self.currencyCode = currencyCode
        self.invoiceDate = invoiceDate
        self.dueDate = dueDate
        self.subTotal = subTotal
        self.totalTax = totalTax
        self.total = total
        self.amountDue = amountDue
        self.amountPaid = amountPaid
        self.amountCredited = amountCredited
        self.pdfBlobId = pdfBlobId
        self.externalUpdatedAt = externalUpdatedAt
    }
}

/// The three outcomes of
/// ``InvoiceRepository/upsert(externalInvoiceId:billingProfileId:payload:)``,
/// reported back to the caller so the sync job can log meaningful metrics.
public enum InvoiceUpsertOutcome: Sendable, Equatable {
    /// No prior row existed for `(billing_profile_id, external_invoice_id)`;
    /// a new ``Invoice`` was inserted with all payload fields.
    case inserted(invoiceId: UUID)
    /// A prior row existed and the payload's `externalUpdatedAt` advanced
    /// past it, so business fields were overwritten and both
    /// `externalUpdatedAt` and `syncedAt` were refreshed.
    case updated(invoiceId: UUID)
    /// A prior row existed and the payload's `externalUpdatedAt` did not
    /// advance past it. Business fields were left untouched, but `syncedAt`
    /// was refreshed to record that the reconciliation attempt happened.
    case skippedUnchanged(invoiceId: UUID)
}

/// Persists and retrieves ``Invoice`` rows for the Xero sync Lambda.
///
/// The repository owns the transactional boundary around the upsert:
/// ``upsert(externalInvoiceId:billingProfileId:payload:)`` performs its
/// lookup and its write inside a single Fluent transaction so that a
/// `synced_at` bump and a business-field update cannot diverge.
public struct InvoiceRepository: Sendable {

    private let database: Database

    /// Creates a new `InvoiceRepository`.
    ///
    /// - Parameter database: The Fluent database connection used for all operations.
    public init(database: Database) {
        self.database = database
    }

    /// Returns the invoice with the given identifier, or `nil` if none exists.
    public func find(id: UUID) async throws -> Invoice? {
        try await Invoice.find(id, on: database)
    }

    /// Returns every invoice in the database.
    ///
    /// Ordered by ascending primary key, which approximates insertion order.
    /// Callers that need a specific ordering should query ``Invoice``
    /// directly.
    public func findAll() async throws -> [Invoice] {
        try await Invoice.query(on: database).all()
    }

    /// Persists a new invoice row.
    ///
    /// - Parameter model: The invoice to save. All required fields must be
    ///   populated; the database generates the `id`.
    /// - Returns: The saved invoice with its database-generated `id`.
    public func create(model: Invoice) async throws -> Invoice {
        try await model.save(on: database)
        return model
    }

    /// Persists changes to an existing invoice row.
    public func update(model: Invoice) async throws -> Invoice {
        try await model.save(on: database)
        return model
    }

    /// Deletes the invoice with the given identifier.
    ///
    /// - Throws: ``RepositoryError/notFound`` if no row matches.
    public func delete(id: UUID) async throws {
        guard let invoice = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await invoice.delete(on: database)
    }

    /// Idempotently mirrors one provider invoice into Navigator.
    ///
    /// The lookup and the write happen in a single Fluent transaction so a
    /// concurrent sync worker cannot observe a half-updated row.
    ///
    /// Three outcomes are possible:
    ///
    /// - No existing row for `(billingProfileId, externalInvoiceId)`: a new
    ///   ``Invoice`` is inserted with every field from the payload and
    ///   `syncedAt = Date()`. Returns ``InvoiceUpsertOutcome/inserted(invoiceId:)``.
    /// - A row exists and `existing.externalUpdatedAt < payload.externalUpdatedAt`:
    ///   business fields are overwritten from the payload, `externalUpdatedAt`
    ///   is advanced to the payload value, and `syncedAt` is stamped.
    ///   Returns ``InvoiceUpsertOutcome/updated(invoiceId:)``.
    /// - A row exists and `existing.externalUpdatedAt >= payload.externalUpdatedAt`:
    ///   only `syncedAt` is bumped — business fields are deliberately left
    ///   untouched so we don't blindly rewrite a row that hasn't actually
    ///   changed upstream. Returns
    ///   ``InvoiceUpsertOutcome/skippedUnchanged(invoiceId:)``.
    ///
    /// Line-item reconciliation is **not** performed by this method. Use
    /// ``upsertWithLineItems(externalInvoiceId:billingProfileId:invoicePayload:lineItems:)``
    /// to upsert the header and replace its line items in a single
    /// transaction.
    ///
    /// - Parameters:
    ///   - externalInvoiceId: The provider-side invoice ID (Xero `InvoiceID`).
    ///   - billingProfileId: The ``EntityBillingProfile/id`` this invoice
    ///     belongs to.
    ///   - payload: The business-field snapshot from the provider.
    /// - Returns: The ``InvoiceUpsertOutcome`` describing what the
    ///   repository did.
    public func upsert(
        externalInvoiceId: String,
        billingProfileId: UUID,
        payload: InvoiceUpsertPayload
    ) async throws -> InvoiceUpsertOutcome {
        try await database.transaction { tx in
            try await Self.upsert(
                externalInvoiceId: externalInvoiceId,
                billingProfileId: billingProfileId,
                payload: payload,
                on: tx
            )
        }
    }

    /// Composes a header upsert with a full line-item replacement in one
    /// transaction.
    ///
    /// Calls ``upsert(externalInvoiceId:billingProfileId:payload:)`` to
    /// resolve the invoice's id and reconcile its header fields, then —
    /// **only when the header outcome is `.inserted` or `.updated`** — calls
    /// ``InvoiceLineItemRepository/replaceAll(forInvoiceId:with:)`` with the
    /// supplied line items. Both happen inside the same Fluent transaction,
    /// so a failure during line-item replacement rolls back the header
    /// changes as well.
    ///
    /// When the header outcome is `.skippedUnchanged` the line items are
    /// left untouched. The contract is:
    /// "if `external_updated_at` did not advance, neither header nor lines
    /// have changed upstream, so don't rewrite either." This matches the
    /// skip-work short-circuit Reporting's sync Lambda relies on.
    ///
    /// - Parameters:
    ///   - externalInvoiceId: The provider-side invoice ID (Xero `InvoiceID`).
    ///   - billingProfileId: The ``EntityBillingProfile/id`` this invoice
    ///     belongs to.
    ///   - invoicePayload: The header business-field snapshot.
    ///   - lineItems: The complete set of line items, in display order.
    /// - Returns: The ``InvoiceUpsertOutcome`` from the header upsert.
    public func upsertWithLineItems(
        externalInvoiceId: String,
        billingProfileId: UUID,
        invoicePayload: InvoiceUpsertPayload,
        lineItems: [InvoiceLineItemPayload]
    ) async throws -> InvoiceUpsertOutcome {
        try await database.transaction { tx in
            let outcome = try await Self.upsert(
                externalInvoiceId: externalInvoiceId,
                billingProfileId: billingProfileId,
                payload: invoicePayload,
                on: tx
            )
            switch outcome {
            case .inserted(let invoiceId), .updated(let invoiceId):
                try await InvoiceLineItemRepository.replaceAll(
                    forInvoiceId: invoiceId,
                    with: lineItems,
                    on: tx
                )
            case .skippedUnchanged:
                break
            }
            return outcome
        }
    }

    /// Internal helper that runs the upsert lookup-and-write against the
    /// supplied database handle without opening a fresh transaction.
    ///
    /// Used by both the public ``upsert(externalInvoiceId:billingProfileId:payload:)``
    /// (which wraps this in a transaction) and
    /// ``upsertWithLineItems(externalInvoiceId:billingProfileId:invoicePayload:lineItems:)``
    /// (which composes it with line-item replacement inside one transaction).
    static func upsert(
        externalInvoiceId: String,
        billingProfileId: UUID,
        payload: InvoiceUpsertPayload,
        on database: any Database
    ) async throws -> InvoiceUpsertOutcome {
        let now = Date()

        let existing = try await Invoice.query(on: database)
            .filter(\.$billingProfile.$id == billingProfileId)
            .filter(\.$externalInvoiceId == externalInvoiceId)
            .first()

        if let existing {
            let existingId = try existing.requireID()

            if existing.externalUpdatedAt < payload.externalUpdatedAt {
                existing.invoiceNumber = payload.invoiceNumber
                existing.reference = payload.reference
                existing.status = payload.status
                existing.invoiceType = payload.invoiceType
                existing.currencyCode = payload.currencyCode
                existing.invoiceDate = payload.invoiceDate
                existing.dueDate = payload.dueDate
                existing.subTotal = payload.subTotal
                existing.totalTax = payload.totalTax
                existing.total = payload.total
                existing.amountDue = payload.amountDue
                existing.amountPaid = payload.amountPaid
                existing.amountCredited = payload.amountCredited
                existing.$pdfBlob.id = payload.pdfBlobId
                existing.externalUpdatedAt = payload.externalUpdatedAt
                existing.syncedAt = now
                try await existing.save(on: database)
                return .updated(invoiceId: existingId)
            } else {
                existing.syncedAt = now
                try await existing.save(on: database)
                return .skippedUnchanged(invoiceId: existingId)
            }
        }

        let invoice = Invoice()
        invoice.$billingProfile.id = billingProfileId
        invoice.externalInvoiceId = externalInvoiceId
        invoice.invoiceNumber = payload.invoiceNumber
        invoice.reference = payload.reference
        invoice.status = payload.status
        invoice.invoiceType = payload.invoiceType
        invoice.currencyCode = payload.currencyCode
        invoice.invoiceDate = payload.invoiceDate
        invoice.dueDate = payload.dueDate
        invoice.subTotal = payload.subTotal
        invoice.totalTax = payload.totalTax
        invoice.total = payload.total
        invoice.amountDue = payload.amountDue
        invoice.amountPaid = payload.amountPaid
        invoice.amountCredited = payload.amountCredited
        invoice.$pdfBlob.id = payload.pdfBlobId
        invoice.externalUpdatedAt = payload.externalUpdatedAt
        invoice.syncedAt = now
        try await invoice.save(on: database)
        return .inserted(invoiceId: try invoice.requireID())
    }
}

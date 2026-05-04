import FluentKit
import Foundation

/// One line item's worth of business data for
/// ``InvoiceLineItemRepository/replaceAll(forInvoiceId:with:)``.
///
/// Carries every column on ``InvoiceLineItem`` except `invoice_id` (passed
/// separately as the replacement scope) and the Navigator-managed
/// `inserted_at` / `updated_at` timestamps (stamped automatically on insert).
public struct InvoiceLineItemPayload: Sendable {
    public var lineNumber: Int32
    public var externalLineItemId: String?
    public var description: String
    public var itemCode: String?
    public var accountCode: String?
    public var quantity: Decimal
    public var unitAmount: Decimal
    public var taxType: String?
    public var taxAmount: Decimal
    public var lineAmount: Decimal
    public var discountRate: Decimal?

    public init(
        lineNumber: Int32,
        externalLineItemId: String?,
        description: String,
        itemCode: String?,
        accountCode: String?,
        quantity: Decimal,
        unitAmount: Decimal,
        taxType: String?,
        taxAmount: Decimal,
        lineAmount: Decimal,
        discountRate: Decimal?
    ) {
        self.lineNumber = lineNumber
        self.externalLineItemId = externalLineItemId
        self.description = description
        self.itemCode = itemCode
        self.accountCode = accountCode
        self.quantity = quantity
        self.unitAmount = unitAmount
        self.taxType = taxType
        self.taxAmount = taxAmount
        self.lineAmount = lineAmount
        self.discountRate = discountRate
    }
}

/// Persists and retrieves ``InvoiceLineItem`` rows for the Xero sync Lambda.
///
/// The repository owns one transactional contract on top of basic CRUD:
/// ``replaceAll(forInvoiceId:with:)`` deletes every existing line item for
/// the given invoice and re-inserts the supplied payloads in a single
/// Fluent transaction. There is no per-row upsert by design — see
/// ``InvoiceLineItem`` for why.
public struct InvoiceLineItemRepository: Sendable {

    private let database: Database

    /// Creates a new `InvoiceLineItemRepository`.
    ///
    /// - Parameter database: The Fluent database connection used for all operations.
    public init(database: Database) {
        self.database = database
    }

    /// Returns the line item with the given identifier, or `nil` if none exists.
    public func find(id: UUID) async throws -> InvoiceLineItem? {
        try await InvoiceLineItem.find(id, on: database)
    }

    /// Returns every line item in the database.
    ///
    /// Useful for tests and debugging; production callers should scope queries
    /// to a specific invoice via ``findForInvoice(invoiceId:)``.
    public func findAll() async throws -> [InvoiceLineItem] {
        try await InvoiceLineItem.query(on: database).all()
    }

    /// Returns the line items for a given invoice, ordered by `line_number`.
    public func findForInvoice(invoiceId: UUID) async throws -> [InvoiceLineItem] {
        try await InvoiceLineItem.query(on: database)
            .filter(\.$invoice.$id == invoiceId)
            .sort(\.$lineNumber, .ascending)
            .all()
    }

    /// Persists a new line item row.
    ///
    /// - Parameter model: The line item to save. `invoice_id`, `line_number`,
    ///   `description`, and the monetary fields must be populated.
    public func create(model: InvoiceLineItem) async throws -> InvoiceLineItem {
        try await model.save(on: database)
        return model
    }

    /// Persists changes to an existing line item row.
    public func update(model: InvoiceLineItem) async throws -> InvoiceLineItem {
        try await model.save(on: database)
        return model
    }

    /// Deletes the line item with the given identifier.
    ///
    /// - Throws: ``RepositoryError/notFound`` if no row matches.
    public func delete(id: UUID) async throws {
        guard let lineItem = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await lineItem.delete(on: database)
    }

    /// Atomically replaces every line item belonging to `invoiceId` with the
    /// supplied payloads.
    ///
    /// Inside a single Fluent transaction:
    /// 1. Deletes every existing ``InvoiceLineItem`` whose `invoice_id`
    ///    matches `invoiceId`.
    /// 2. Inserts one new row per payload, in payload order.
    ///
    /// If any insert fails the transaction is rolled back and the original
    /// rows survive intact — there is no half-replaced state.
    ///
    /// Passing an empty `lineItems` array is a valid call: it deletes the
    /// existing set for the invoice and leaves the line-item set empty. This
    /// supports the case of a Xero invoice whose lines have been removed.
    ///
    /// This method is the **only** sanctioned mutation surface for
    /// `invoice_line_items` from the sync path. Per-row upserts are not
    /// supported — matching `external_line_item_id` does **not** preserve
    /// the existing primary key, by design.
    ///
    /// - Parameters:
    ///   - invoiceId: The ``Invoice/id`` whose line items to replace.
    ///   - lineItems: The new set of line items, in display order. May be empty.
    public func replaceAll(
        forInvoiceId invoiceId: UUID,
        with lineItems: [InvoiceLineItemPayload]
    ) async throws {
        try await database.transaction { tx in
            try await Self.replaceAll(
                forInvoiceId: invoiceId,
                with: lineItems,
                on: tx
            )
        }
    }

    /// Internal helper: performs the delete-then-insert sequence on the given
    /// database handle without opening a fresh transaction.
    ///
    /// Used by ``replaceAll(forInvoiceId:with:)`` (which wraps it in a
    /// transaction) and by ``InvoiceRepository/upsertWithLineItems(externalInvoiceId:billingProfileId:invoicePayload:lineItems:)``
    /// (which composes it inside the same transaction as the header upsert).
    static func replaceAll(
        forInvoiceId invoiceId: UUID,
        with lineItems: [InvoiceLineItemPayload],
        on database: any Database
    ) async throws {
        try await InvoiceLineItem.query(on: database)
            .filter(\.$invoice.$id == invoiceId)
            .delete()

        for payload in lineItems {
            let row = InvoiceLineItem()
            row.$invoice.id = invoiceId
            row.lineNumber = payload.lineNumber
            row.externalLineItemId = payload.externalLineItemId
            row.description = payload.description
            row.itemCode = payload.itemCode
            row.accountCode = payload.accountCode
            row.quantity = payload.quantity
            row.unitAmount = payload.unitAmount
            row.taxType = payload.taxType
            row.taxAmount = payload.taxAmount
            row.lineAmount = payload.lineAmount
            row.discountRate = payload.discountRate
            try await row.save(on: database)
        }
    }
}

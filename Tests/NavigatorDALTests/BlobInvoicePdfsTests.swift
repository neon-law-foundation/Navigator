import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import SQLKit
import Testing
import Vapor

@Suite("Blob invoice_pdfs referencedBy")
struct BlobInvoicePdfsTests {

    @Test("Blob with referencedBy = .invoicePdfs round-trips through the database")
    func testInvoicePdfsRoundTrip() async throws {
        try await withDatabase { db in
            let referencedById = UUID()
            let blob = Blob()
            blob.objectStorageUrl = "s3://bucket/invoices/xero-INV-0001.pdf"
            blob.referencedBy = .invoicePdfs
            blob.referencedById = referencedById
            try await blob.save(on: db)

            let reloaded = try #require(try await Blob.find(blob.id, on: db))
            #expect(reloaded.referencedBy == .invoicePdfs)
            #expect(reloaded.objectStorageUrl == "s3://bucket/invoices/xero-INV-0001.pdf")
            #expect(reloaded.referencedById == referencedById)
        }
    }

    @Test("blobs_referenced_by_check CHECK constraint rejects unknown referenced_by values on Postgres")
    func testCheckConstraintRejectsInvalidValue() async throws {
        try await withDatabase { db in
            guard let sql = db as? SQLDatabase else {
                return
            }
            // The CHECK constraint is Postgres-only; SQLite (used in the default test
            // harness) does not support `ALTER TABLE ... ADD CONSTRAINT ... CHECK`, so
            // skip the assertion there. The assertion only runs when tests are pointed
            // at a real Postgres instance.
            guard sql.dialect.name == "postgresql" else {
                return
            }

            await #expect(throws: (any Error).self) {
                try await sql.raw(
                    """
                    INSERT INTO blobs
                        (object_storage_url, referenced_by, referenced_by_id,
                         inserted_at, updated_at)
                    VALUES
                        ('s3://bucket/bad.pdf', 'nonsense', '00000000-0000-0000-0000-000000000001',
                         CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """
                ).run()
            }
        }
    }
}

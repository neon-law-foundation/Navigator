import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Letter Database Operations")
struct LetterTests {

    @Test("Can create a letter and retrieve it by ID")
    func testCreateAndFindByID() async throws {
        try await withDatabase { db in
            let mailroom = Mailroom()
            mailroom.name = "Test Mail Center"
            mailroom.mailboxStart = 1000
            mailroom.mailboxEnd = 1999
            try await mailroom.save(on: db)

            let letter = Letter()
            letter.$mailroom.id = mailroom.id!

            let repo = LetterRepository(database: db)
            let created = try await repo.create(letter: letter)
            #expect(created.id != nil)

            let found = try await repo.find(id: created.id!)
            #expect(found != nil)
            #expect(found?.$mailroom.id == mailroom.id)
            #expect(found?.$scannedDocument.id == nil)
        }
    }

    @Test("Can create a letter with a scanned document blob")
    func testCreateLetterWithBlob() async throws {
        try await withDatabase { db in
            let mailroom = Mailroom()
            mailroom.name = "Document Mail Center"
            mailroom.mailboxStart = 2000
            mailroom.mailboxEnd = 2999
            try await mailroom.save(on: db)

            let blob = Blob()
            blob.objectStorageUrl = "s3://bucket/letters/scan.pdf"
            blob.referencedBy = .letters
            blob.referencedById = UUID()
            try await blob.save(on: db)

            let letter = Letter()
            letter.$mailroom.id = mailroom.id!
            letter.$scannedDocument.id = blob.id

            let repo = LetterRepository(database: db)
            let created = try await repo.create(letter: letter)
            #expect(created.$scannedDocument.id == blob.id)

            let found = try await repo.find(id: created.id!)
            #expect(found?.$scannedDocument.id == blob.id)
        }
    }

    @Test("Can find all letters for a mailroom")
    func testFindByMailroom() async throws {
        try await withDatabase { db in
            let mailroom = Mailroom()
            mailroom.name = "Bulk Mail Center"
            mailroom.mailboxStart = 3000
            mailroom.mailboxEnd = 3999
            try await mailroom.save(on: db)

            let repo = LetterRepository(database: db)

            let letter1 = Letter()
            letter1.$mailroom.id = mailroom.id!
            _ = try await repo.create(letter: letter1)

            let letter2 = Letter()
            letter2.$mailroom.id = mailroom.id!
            _ = try await repo.create(letter: letter2)

            let letters = try await repo.findByMailroom(mailroomId: mailroom.id!)
            #expect(letters.count == 2)
        }
    }

    @Test("Can eager load mailroom from letter")
    func testEagerLoadMailroom() async throws {
        try await withDatabase { db in
            let mailroom = Mailroom()
            mailroom.name = "Eager Load Mail"
            mailroom.mailboxStart = 4000
            mailroom.mailboxEnd = 4999
            try await mailroom.save(on: db)

            let letter = Letter()
            letter.$mailroom.id = mailroom.id!
            try await letter.save(on: db)

            let loaded = try await Letter.query(on: db)
                .filter(\.$id == letter.id!)
                .with(\.$mailroom)
                .first()

            #expect(loaded?.mailroom.name == "Eager Load Mail")
        }
    }

    @Test("Can delete a letter")
    func testDeleteLetter() async throws {
        try await withDatabase { db in
            let mailroom = Mailroom()
            mailroom.name = "Delete Mail Center"
            mailroom.mailboxStart = 5000
            mailroom.mailboxEnd = 5999
            try await mailroom.save(on: db)

            let letter = Letter()
            letter.$mailroom.id = mailroom.id!

            let repo = LetterRepository(database: db)
            let created = try await repo.create(letter: letter)
            let id = created.id!

            try await repo.delete(id: id)

            let found = try await repo.find(id: id)
            #expect(found == nil)
        }
    }
}

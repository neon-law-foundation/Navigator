import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Mailroom Database Operations")
struct MailroomTests {

    @Test("Can create a mailroom and retrieve it by ID")
    func testCreateAndFindByID() async throws {
        try await withDatabase { db in
            let repo = MailroomRepository(database: db)

            let mailroom = Mailroom()
            mailroom.name = "Test Mail Center"
            mailroom.mailboxStart = 1000
            mailroom.mailboxEnd = 1999
            mailroom.capacity = 1000

            let created = try await repo.create(mailroom: mailroom)
            #expect(created.id != nil)

            let found = try await repo.find(id: created.id!)
            #expect(found?.name == "Test Mail Center")
            #expect(found?.mailboxStart == 1000)
            #expect(found?.mailboxEnd == 1999)
            #expect(found?.capacity == 1000)
        }
    }

    @Test("Can find a mailroom by name")
    func testFindByName() async throws {
        try await withDatabase { db in
            let repo = MailroomRepository(database: db)

            let mailroom = Mailroom()
            mailroom.name = "Ridgeview Mail Center"
            mailroom.mailboxStart = 9000
            mailroom.mailboxEnd = 9999
            _ = try await repo.create(mailroom: mailroom)

            let found = try await repo.findByName("Ridgeview Mail Center")
            #expect(found != nil)
            #expect(found?.mailboxStart == 9000)
        }
    }

    @Test("Unique name constraint throws on duplicate")
    func testUniqueNameConstraint() async throws {
        try await withDatabase { db in
            let repo = MailroomRepository(database: db)

            let first = Mailroom()
            first.name = "Unique Center"
            first.mailboxStart = 100
            first.mailboxEnd = 199
            _ = try await repo.create(mailroom: first)

            let duplicate = Mailroom()
            duplicate.name = "Unique Center"
            duplicate.mailboxStart = 200
            duplicate.mailboxEnd = 299

            await #expect(throws: Error.self) {
                try await repo.create(mailroom: duplicate)
            }
        }
    }

    @Test("An address with mailroom_id set loads its mailroom via eager load")
    func testAddressEagerLoadsMailroom() async throws {
        try await withDatabase { db in
            let mailroom = Mailroom()
            mailroom.name = "Eager Load Center"
            mailroom.mailboxStart = 500
            mailroom.mailboxEnd = 599
            try await mailroom.save(on: db)

            let address = Address()
            address.street = "123 Test St"
            address.city = "Reno"
            address.country = "USA"
            address.isVerified = true
            address.$mailroom.id = mailroom.id
            try await address.save(on: db)

            let loaded = try await Address.query(on: db)
                .filter(\.$id == address.id!)
                .with(\.$mailroom)
                .first()

            #expect(loaded?.mailroom != nil)
            #expect(loaded?.mailroom?.name == "Eager Load Center")
        }
    }

    @Test("An address without mailroom_id has mailroom == nil")
    func testAddressWithoutMailroom() async throws {
        try await withDatabase { db in
            let address = Address()
            address.street = "456 No Mailroom St"
            address.city = "Reno"
            address.country = "USA"
            address.isVerified = false
            try await address.save(on: db)

            let loaded = try await Address.query(on: db)
                .filter(\.$id == address.id!)
                .with(\.$mailroom)
                .first()

            #expect(loaded?.mailroom == nil)
        }
    }

    @Test("Can delete a mailroom")
    func testDeleteMailroom() async throws {
        try await withDatabase { db in
            let repo = MailroomRepository(database: db)

            let mailroom = Mailroom()
            mailroom.name = "Delete Me Center"
            mailroom.mailboxStart = 300
            mailroom.mailboxEnd = 399
            let created = try await repo.create(mailroom: mailroom)
            let id = created.id!

            try await repo.delete(id: id)

            let found = try await repo.find(id: id)
            #expect(found == nil)
        }
    }
}

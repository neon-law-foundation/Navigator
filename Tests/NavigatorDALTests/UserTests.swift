import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("User Database Operations")
struct UserTests {

    @Test("User can be created with valid data")
    func testCreateUser() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "user@example.com"
            person.name = "User Person"
            try await person.save(on: db)

            let user = User()
            user.$person.id = person.id!
            user.role = .client
            user.sub = "test-sub-123"

            try await user.save(on: db)

            #expect(user.id != nil)
            #expect(user.role == .client)
            #expect(user.sub == "test-sub-123")
            #expect(user.insertedAt != nil)
            #expect(user.updatedAt != nil)
        }
    }

    @Test("User sub must be unique when set")
    func testSubUniqueness() async throws {
        try await withDatabase { db in
            let person1 = Person()
            person1.email = "user1@example.com"
            person1.name = "User One"
            try await person1.save(on: db)

            let person2 = Person()
            person2.email = "user2@example.com"
            person2.name = "User Two"
            try await person2.save(on: db)

            let user1 = User()
            user1.$person.id = person1.id!
            user1.role = .client
            user1.sub = "duplicate-sub"
            try await user1.save(on: db)

            let user2 = User()
            user2.$person.id = person2.id!
            user2.role = .staff
            user2.sub = "duplicate-sub"

            await #expect(throws: Error.self) {
                try await user2.save(on: db)
            }
        }
    }

    @Test("User requires person reference")
    func testPersonRequired() async throws {
        try await withDatabase { db in
            let user = User()
            user.role = .client

            await #expect(throws: Error.self) {
                try await user.save(on: db)
            }
        }
    }

    @Test("User can have different roles")
    func testUserRoles() async throws {
        try await withDatabase { db in
            let customer = Person()
            customer.email = "customer@example.com"
            customer.name = "Customer"
            try await customer.save(on: db)

            let staff = Person()
            staff.email = "staff@example.com"
            staff.name = "Staff Member"
            try await staff.save(on: db)

            let admin = Person()
            admin.email = "admin@example.com"
            admin.name = "Administrator"
            try await admin.save(on: db)

            let customerUser = User()
            customerUser.$person.id = customer.id!
            customerUser.role = .client
            try await customerUser.save(on: db)

            let staffUser = User()
            staffUser.$person.id = staff.id!
            staffUser.role = .staff
            try await staffUser.save(on: db)

            let adminUser = User()
            adminUser.$person.id = admin.id!
            adminUser.role = .admin
            try await adminUser.save(on: db)

            let users = try await User.query(on: db).all()
            #expect(users.count == 3)
            #expect(users.contains(where: { $0.role == .client }))
            #expect(users.contains(where: { $0.role == .staff }))
            #expect(users.contains(where: { $0.role == .admin }))
        }
    }

    @Test("User can be queried with person relationship")
    func testQueryWithPerson() async throws {
        try await withApplication { app in
            let person = Person()
            person.email = "related@example.com"
            person.name = "Related Person"
            try await person.save(on: app.db)

            let user = User()
            user.$person.id = person.id!
            user.role = .staff

            try await user.save(on: app.db)

            let found = try await User.query(on: app.db)
                .with(\.$person)
                .filter(\.$person.$id == person.id!)
                .first()

            #expect(found != nil)
            #expect(found?.person.email == "related@example.com")
        }
    }

    @Test("findBySub returns user when sub matches")
    func testFindBySubFound() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "sub-user@example.com"
            person.name = "Sub User"
            try await person.save(on: db)

            let user = User()
            user.$person.id = person.id!
            user.role = .client
            user.sub = "find-by-sub-test"
            try await user.save(on: db)

            let repo = UserRepository(database: db)
            let found = try await repo.findBySub("find-by-sub-test")

            #expect(found != nil)
            #expect(found?.sub == "find-by-sub-test")
            #expect(found?.role == .client)
        }
    }

    @Test("findBySub returns nil when sub does not match")
    func testFindBySubNotFound() async throws {
        try await withDatabase { db in
            let repo = UserRepository(database: db)
            let found = try await repo.findBySub("nonexistent-sub")
            #expect(found == nil)
        }
    }

    @Test("User can be updated")
    func testUpdateUser() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "update-user@example.com"
            person.name = "Update User"
            try await person.save(on: db)

            let user = User()
            user.$person.id = person.id!
            user.role = .client
            try await user.save(on: db)

            user.role = .staff
            try await user.save(on: db)

            let updated = try await User.query(on: db)
                .filter(\.$id == user.id!)
                .first()

            #expect(updated?.role == .staff)
        }
    }
}

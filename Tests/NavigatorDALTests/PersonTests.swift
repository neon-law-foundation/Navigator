import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Person Database Operations")
struct PersonTests {

    @Test("Person can be created with valid data")
    func testCreatePerson() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "test@example.com"
            person.name = "Test Person"

            try await person.save(on: db)

            #expect(person.id != nil)
            #expect(person.email == "test@example.com")
            #expect(person.name == "Test Person")
            #expect(person.insertedAt != nil)
            #expect(person.updatedAt != nil)
        }
    }

    @Test("Person email must be unique")
    func testEmailUniqueness() async throws {
        try await withDatabase { db in
            let person1 = Person()
            person1.email = "unique@example.com"
            person1.name = "First Person"
            try await person1.save(on: db)

            let person2 = Person()
            person2.email = "unique@example.com"
            person2.name = "Second Person"

            await #expect(throws: Error.self) {
                try await person2.save(on: db)
            }
        }
    }

    @Test("Person can be queried by email")
    func testQueryByEmail() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "query@example.com"
            person.name = "Query Person"
            try await person.save(on: db)

            let found = try await Person.query(on: db)
                .filter(\.$email == "query@example.com")
                .first()

            #expect(found != nil)
            #expect(found?.email == "query@example.com")
            #expect(found?.name == "Query Person")
        }
    }

    @Test("Person can be updated")
    func testUpdatePerson() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "update@example.com"
            person.name = "Original Name"
            try await person.save(on: db)

            let originalUpdatedAt = person.updatedAt

            person.name = "Updated Name"
            try await person.save(on: db)

            let updated = try await Person.query(on: db)
                .filter(\.$email == "update@example.com")
                .first()

            #expect(updated?.name == "Updated Name")
            #expect(updated?.updatedAt != originalUpdatedAt)
        }
    }

    @Test("Person can be deleted")
    func testDeletePerson() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "delete@example.com"
            person.name = "Delete Me"
            try await person.save(on: db)

            try await person.delete(on: db)

            let found = try await Person.query(on: db)
                .filter(\.$email == "delete@example.com")
                .first()

            #expect(found == nil)
        }
    }

    @Test("Multiple people can be created")
    func testMultiplePeople() async throws {
        try await withDatabase { db in
            let person1 = Person()
            person1.email = "person1@example.com"
            person1.name = "Person One"
            try await person1.save(on: db)

            let person2 = Person()
            person2.email = "person2@example.com"
            person2.name = "Person Two"
            try await person2.save(on: db)

            let count = try await Person.query(on: db).count()
            #expect(count == 2)
        }
    }
}

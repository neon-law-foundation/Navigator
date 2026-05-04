import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Address Database Operations")
struct AddressTests {

    @Test("Address can be created for entity")
    func testCreateAddressForEntity() async throws {
        try await withDatabase { db in
            // Create jurisdiction
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            // Create entity type
            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Multi Member LLC"
            try await entityType.save(on: db)

            // Create entity
            let entity = Entity()
            entity.name = "Test Company LLC"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            // Create address for entity
            let address = Address()
            address.$entity.id = entity.id!
            address.street = "123 Main St"
            address.city = "Reno"
            address.state = "NV"
            address.zip = "89501"
            address.country = "USA"
            address.isVerified = true

            try await address.save(on: db)

            #expect(address.id != nil)
            #expect(address.street == "123 Main St")
            #expect(address.city == "Reno")
            #expect(address.isVerified == true)
            #expect(address.insertedAt != nil)
            #expect(address.updatedAt != nil)
        }
    }

    @Test("Address can be created for person")
    func testCreateAddressForPerson() async throws {
        try await withDatabase { db in
            // Create person
            let person = Person()
            person.email = "resident@example.com"
            person.name = "Resident Person"
            try await person.save(on: db)

            // Create address for person
            let address = Address()
            address.$person.id = person.id!
            address.street = "456 Oak Ave"
            address.city = "Las Vegas"
            address.state = "NV"
            address.zip = "89102"
            address.country = "USA"
            address.isVerified = false

            try await address.save(on: db)

            #expect(address.id != nil)
            #expect(address.street == "456 Oak Ave")
            #expect(address.city == "Las Vegas")
            #expect(address.isVerified == false)
        }
    }

    @Test("Address requires street and city")
    func testRequiredFields() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "test@example.com"
            person.name = "Test Person"
            try await person.save(on: db)

            let address = Address()
            address.$person.id = person.id!
            address.country = "USA"
            address.isVerified = false
            // Missing street and city

            // Expect error for missing required fields
            await #expect(throws: Error.self) {
                try await address.save(on: db)
            }
        }
    }

    @Test("Address can be queried by entity")
    func testQueryByEntity() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Multi Member LLC"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "Query Test LLC"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            let address = Address()
            address.$entity.id = entity.id!
            address.street = "789 Pine St"
            address.city = "Reno"
            address.country = "USA"
            address.isVerified = true
            try await address.save(on: db)

            let found = try await Address.query(on: db)
                .filter(\.$entity.$id == entity.id!)
                .first()

            #expect(found != nil)
            #expect(found?.street == "789 Pine St")
        }
    }

    @Test("Address can be queried by person")
    func testQueryByPerson() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "address-query@example.com"
            person.name = "Address Query Person"
            try await person.save(on: db)

            let address = Address()
            address.$person.id = person.id!
            address.street = "321 Elm St"
            address.city = "Henderson"
            address.country = "USA"
            address.isVerified = true
            try await address.save(on: db)

            let found = try await Address.query(on: db)
                .filter(\.$person.$id == person.id!)
                .first()

            #expect(found != nil)
            #expect(found?.street == "321 Elm St")
        }
    }

    @Test("Address can be updated")
    func testUpdateAddress() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "update-address@example.com"
            person.name = "Update Address Person"
            try await person.save(on: db)

            let address = Address()
            address.$person.id = person.id!
            address.street = "Old Street"
            address.city = "Old City"
            address.country = "USA"
            address.isVerified = false
            try await address.save(on: db)

            // Update address
            address.street = "New Street"
            address.city = "New City"
            address.isVerified = true
            try await address.save(on: db)

            let updated = try await Address.query(on: db)
                .filter(\.$id == address.id!)
                .first()

            #expect(updated?.street == "New Street")
            #expect(updated?.city == "New City")
            #expect(updated?.isVerified == true)
        }
    }

    @Test("Multiple addresses can be created for same entity")
    func testMultipleAddressesForEntity() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Multi Member LLC"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "Multi-Location LLC"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            // Create main office address
            let mainOffice = Address()
            mainOffice.$entity.id = entity.id!
            mainOffice.street = "100 Main St"
            mainOffice.city = "Reno"
            mainOffice.country = "USA"
            mainOffice.isVerified = true
            try await mainOffice.save(on: db)

            // Create branch office address
            let branchOffice = Address()
            branchOffice.$entity.id = entity.id!
            branchOffice.street = "200 Branch Ave"
            branchOffice.city = "Las Vegas"
            branchOffice.country = "USA"
            branchOffice.isVerified = true
            try await branchOffice.save(on: db)

            let addresses = try await Address.query(on: db)
                .filter(\.$entity.$id == entity.id!)
                .all()

            #expect(addresses.count == 2)
        }
    }

    @Test("Address with no zip code is allowed")
    func testAddressWithoutZip() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "no-zip@example.com"
            person.name = "No Zip Person"
            try await person.save(on: db)

            let address = Address()
            address.$person.id = person.id!
            address.street = "International Address"
            address.city = "Foreign City"
            address.state = nil
            address.zip = nil
            address.country = "Other Country"
            address.isVerified = false

            try await address.save(on: db)

            #expect(address.id != nil)
            #expect(address.zip == nil)
            #expect(address.state == nil)
        }
    }
}

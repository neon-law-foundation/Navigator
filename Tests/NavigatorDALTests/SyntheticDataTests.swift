import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Synthetic Data Tests - Edge Cases and Complex Scenarios")
struct SyntheticDataTests {

    // MARK: - Complex Credential Scenarios

    @Test("Attorney licensed in multiple states can have different license numbers")
    func testMultiStateLicensing() async throws {
        try await withDatabase { db in
            // Create attorney
            let attorney = Person()
            attorney.email = "multistate.attorney@lawfirm.com"
            attorney.name = "Sarah MultiState"
            try await attorney.save(on: db)

            // Create 5 different state jurisdictions
            let states = ["Texas", "Florida", "New York", "Illinois", "Georgia"]
            let codes = ["TX", "FL", "NY", "IL", "GA"]

            for (index, state) in states.enumerated() {
                let jurisdiction = Jurisdiction()
                jurisdiction.name = state
                jurisdiction.code = codes[index]
                jurisdiction.jurisdictionType = .state
                try await jurisdiction.save(on: db)

                // Create credential with different license number
                let credential = Credential()
                credential.$person.id = attorney.id!
                credential.$jurisdiction.id = jurisdiction.id!
                credential.licenseNumber = "LIC-\(codes[index])-\(10000 + index)"
                try await credential.save(on: db)
            }

            // Verify all credentials exist
            let credentials = try await Credential.query(on: db)
                .filter(\.$person.$id == attorney.id!)
                .all()

            #expect(credentials.count == 5, "Should have 5 state licenses")
        }
    }

    @Test("Cannot create duplicate license in same jurisdiction")
    func testDuplicateLicenseInJurisdiction() async throws {
        try await withDatabase { db in
            // Create two attorneys
            let attorney1 = Person()
            attorney1.email = "attorney1@law.com"
            attorney1.name = "First Attorney"
            try await attorney1.save(on: db)

            let attorney2 = Person()
            attorney2.email = "attorney2@law.com"
            attorney2.name = "Second Attorney"
            try await attorney2.save(on: db)

            // Create jurisdiction
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Delaware"
            jurisdiction.code = "DE"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            // First attorney gets license
            let credential1 = Credential()
            credential1.$person.id = attorney1.id!
            credential1.$jurisdiction.id = jurisdiction.id!
            credential1.licenseNumber = "DE-12345"
            try await credential1.save(on: db)

            // Second attorney tries to get same license number - should fail
            let credential2 = Credential()
            credential2.$person.id = attorney2.id!
            credential2.$jurisdiction.id = jurisdiction.id!
            credential2.licenseNumber = "DE-12345"

            await #expect(throws: Error.self) {
                try await credential2.save(on: db)
            }
        }
    }

    @Test("Attorney can update their license number in a jurisdiction")
    func testUpdateLicenseNumber() async throws {
        try await withDatabase { db in
            // Create attorney and jurisdiction
            let attorney = Person()
            attorney.email = "update.attorney@law.com"
            attorney.name = "Update Attorney"
            try await attorney.save(on: db)

            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Montana"
            jurisdiction.code = "MT"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            // Create initial credential
            let credential = Credential()
            credential.$person.id = attorney.id!
            credential.$jurisdiction.id = jurisdiction.id!
            credential.licenseNumber = "MT-OLD-123"
            try await credential.save(on: db)

            // Update license number
            credential.licenseNumber = "MT-NEW-456"
            try await credential.save(on: db)

            // Verify update
            let updated = try await Credential.query(on: db)
                .filter(\.$id == credential.id!)
                .first()

            #expect(updated?.licenseNumber == "MT-NEW-456")
        }
    }

    // MARK: - Complex Entity Scenarios

    @Test("Entity can change its type")
    func testEntityTypeChange() async throws {
        try await withDatabase { db in
            // Create jurisdiction
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Colorado"
            jurisdiction.code = "CO"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            // Create two entity types
            let llcType = EntityType()
            llcType.$jurisdiction.id = jurisdiction.id!
            llcType.name = "Single Member LLC"
            try await llcType.save(on: db)

            let corpType = EntityType()
            corpType.$jurisdiction.id = jurisdiction.id!
            corpType.name = "C-Corp"
            try await corpType.save(on: db)

            // Create entity as LLC
            let entity = Entity()
            entity.name = "Evolving Company"
            entity.$legalEntityType.id = llcType.id!
            try await entity.save(on: db)

            // Convert to C-Corp
            entity.$legalEntityType.id = corpType.id!
            try await entity.save(on: db)

            // Verify change
            let updated = try await Entity.query(on: db)
                .filter(\.$id == entity.id!)
                .with(\.$legalEntityType)
                .first()

            #expect(updated?.legalEntityType.name == "C-Corp")
        }
    }

    @Test("Multiple entities can have the same name if different types")
    func testSameNameDifferentTypes() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Oregon"
            jurisdiction.code = "OR"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let llcType = EntityType()
            llcType.$jurisdiction.id = jurisdiction.id!
            llcType.name = "LLC"
            try await llcType.save(on: db)

            let corpType = EntityType()
            corpType.$jurisdiction.id = jurisdiction.id!
            corpType.name = "Corporation"
            try await corpType.save(on: db)

            // Same name, different types
            let llcEntity = Entity()
            llcEntity.name = "Tech Solutions"
            llcEntity.$legalEntityType.id = llcType.id!
            try await llcEntity.save(on: db)

            let corpEntity = Entity()
            corpEntity.name = "Tech Solutions"
            corpEntity.$legalEntityType.id = corpType.id!
            try await corpEntity.save(on: db)

            // Both should exist
            let entities = try await Entity.query(on: db)
                .filter(\.$name == "Tech Solutions")
                .all()

            #expect(entities.count == 2)
        }
    }

    @Test("Entity with multiple addresses across different locations")
    func testMultiLocationEntity() async throws {
        try await withDatabase { db in
            // Create entity
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Arizona"
            jurisdiction.code = "AZ"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Multi Member LLC"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "National Franchise LLC"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            // Create 4 different locations
            let locations = [
                ("123 Phoenix St", "Phoenix", "AZ", "85001"),
                ("456 Tucson Ave", "Tucson", "AZ", "85701"),
                ("789 Flagstaff Rd", "Flagstaff", "AZ", "86001"),
                ("321 Scottsdale Blvd", "Scottsdale", "AZ", "85250"),
            ]

            for location in locations {
                let address = Address()
                address.$entity.id = entity.id!
                address.street = location.0
                address.city = location.1
                address.state = location.2
                address.zip = location.3
                address.country = "USA"
                address.isVerified = true
                try await address.save(on: db)
            }

            // Verify all addresses
            let addresses = try await Address.query(on: db)
                .filter(\.$entity.$id == entity.id!)
                .all()

            #expect(addresses.count == 4, "Entity should have 4 locations")
        }
    }

    // MARK: - Complex User Scenarios

    @Test("Person can have multiple user accounts with different roles")
    func testPersonWithMultipleUserRoles() async throws {
        try await withDatabase { db in
            // Create person
            let person = Person()
            person.email = "multirole@example.com"
            person.name = "Multi Role User"
            try await person.save(on: db)

            // This test verifies our understanding: A person can only have ONE user account
            // because of the person_id foreign key relationship

            let user1 = User()
            user1.$person.id = person.id!
            user1.role = .client
            user1.sub = "sub-customer-123"
            try await user1.save(on: db)

            // Attempt to create second user for same person should succeed
            // (Current schema allows this)
            let user2 = User()
            user2.$person.id = person.id!
            user2.role = .staff
            user2.sub = "sub-staff-456"
            try await user2.save(on: db)

            let users = try await User.query(on: db)
                .filter(\.$person.$id == person.id!)
                .all()

            #expect(users.count == 2, "Person can have multiple user accounts")
        }
    }

    @Test("User role can be upgraded from customer to staff to admin")
    func testUserRoleProgression() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "promoted@example.com"
            person.name = "Promoted User"
            try await person.save(on: db)

            // Start as customer
            let user = User()
            user.$person.id = person.id!
            user.role = .client
            try await user.save(on: db)

            #expect(user.role == .client)

            // Promote to staff
            user.role = .staff
            try await user.save(on: db)

            let asStaff = try await User.query(on: db).filter(\.$id == user.id!).first()
            #expect(asStaff?.role == .staff)

            // Promote to admin
            user.role = .admin
            try await user.save(on: db)

            let asAdmin = try await User.query(on: db).filter(\.$id == user.id!).first()
            #expect(asAdmin?.role == .admin)
        }
    }

    // MARK: - Complex Address Scenarios

    @Test("Person moves from one address to another")
    func testPersonMovingAddresses() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "nomad@example.com"
            person.name = "Nomadic Person"
            try await person.save(on: db)

            // Create old address
            let oldAddress = Address()
            oldAddress.$person.id = person.id!
            oldAddress.street = "123 Old Street"
            oldAddress.city = "Old City"
            oldAddress.state = "NY"
            oldAddress.zip = "10001"
            oldAddress.country = "USA"
            oldAddress.isVerified = true
            try await oldAddress.save(on: db)

            // Create new address
            let newAddress = Address()
            newAddress.$person.id = person.id!
            newAddress.street = "456 New Avenue"
            newAddress.city = "New City"
            newAddress.state = "CA"
            newAddress.zip = "90001"
            newAddress.country = "USA"
            newAddress.isVerified = false
            try await newAddress.save(on: db)

            // Person can have multiple addresses in history
            let addresses = try await Address.query(on: db)
                .filter(\.$person.$id == person.id!)
                .all()

            #expect(addresses.count == 2)
        }
    }

    @Test("International address without state or zip")
    func testInternationalAddress() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Germany"
            jurisdiction.code = "DE"
            jurisdiction.jurisdictionType = .country
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "GmbH"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "Deutsche Tech GmbH"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            // International address
            let address = Address()
            address.$entity.id = entity.id!
            address.street = "Hauptstraße 123"
            address.city = "Berlin"
            address.state = nil  // Germany doesn't use states
            address.zip = nil  // Different postal system
            address.country = "Germany"
            address.isVerified = true
            try await address.save(on: db)

            #expect(address.id != nil)
            #expect(address.state == nil)
            #expect(address.zip == nil)
        }
    }

    @Test("Address verification status can be toggled")
    func testAddressVerification() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "verify@example.com"
            person.name = "Verify Person"
            try await person.save(on: db)

            let address = Address()
            address.$person.id = person.id!
            address.street = "789 Verify Lane"
            address.city = "Verify City"
            address.state = "WA"
            address.zip = "98101"
            address.country = "USA"
            address.isVerified = false
            try await address.save(on: db)

            #expect(address.isVerified == false)

            // Mark as verified
            address.isVerified = true
            try await address.save(on: db)

            let verified = try await Address.query(on: db).filter(\.$id == address.id!).first()
            #expect(verified?.isVerified == true)
        }
    }

    // MARK: - Complex Cross-Model Scenarios

    @Test("Complete attorney workflow - person, user, credentials, entity practice")
    func testCompleteAttorneyWorkflow() async throws {
        try await withDatabase { db in
            // Create attorney person
            let attorney = Person()
            attorney.email = "fullworkflow@lawfirm.com"
            attorney.name = "Complete Workflow Attorney"
            try await attorney.save(on: db)

            // Create user account
            let user = User()
            user.$person.id = attorney.id!
            user.role = .staff
            user.sub = "auth0|workflow123"
            try await user.save(on: db)

            // Create two bar licenses
            let ny = Jurisdiction()
            ny.name = "New York"
            ny.code = "NY"
            ny.jurisdictionType = .state
            try await ny.save(on: db)

            let nj = Jurisdiction()
            nj.name = "New Jersey"
            nj.code = "NJ"
            nj.jurisdictionType = .state
            try await nj.save(on: db)

            let nyCredential = Credential()
            nyCredential.$person.id = attorney.id!
            nyCredential.$jurisdiction.id = ny.id!
            nyCredential.licenseNumber = "NY-987654"
            try await nyCredential.save(on: db)

            let njCredential = Credential()
            njCredential.$person.id = attorney.id!
            njCredential.$jurisdiction.id = nj.id!
            njCredential.licenseNumber = "NJ-123456"
            try await njCredential.save(on: db)

            // Create law firm entity
            let entityType = EntityType()
            entityType.$jurisdiction.id = ny.id!
            entityType.name = "Professional LLC"
            try await entityType.save(on: db)

            let lawFirm = Entity()
            lawFirm.name = "Workflow Law PLLC"
            lawFirm.$legalEntityType.id = entityType.id!
            try await lawFirm.save(on: db)

            // Create firm address
            let firmAddress = Address()
            firmAddress.$entity.id = lawFirm.id!
            firmAddress.street = "100 Broadway"
            firmAddress.city = "New York"
            firmAddress.state = "NY"
            firmAddress.zip = "10005"
            firmAddress.country = "USA"
            firmAddress.isVerified = true
            try await firmAddress.save(on: db)

            // Verify everything exists and is linked
            let foundAttorney = try await Person.query(on: db)
                .filter(\.$id == attorney.id!)
                .first()
            #expect(foundAttorney != nil)

            let foundUser = try await User.query(on: db)
                .filter(\.$person.$id == attorney.id!)
                .first()
            #expect(foundUser != nil)

            let credentials = try await Credential.query(on: db)
                .filter(\.$person.$id == attorney.id!)
                .all()
            #expect(credentials.count == 2)

            let foundFirm = try await Entity.query(on: db)
                .filter(\.$id == lawFirm.id!)
                .first()
            #expect(foundFirm != nil)

            let foundAddress = try await Address.query(on: db)
                .filter(\.$entity.$id == lawFirm.id!)
                .first()
            #expect(foundAddress != nil)
        }
    }

    @Test("Cascade delete behavior - deleting person with credentials fails")
    func testNoCascadeDelete() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "deleteme@example.com"
            person.name = "Delete Me"
            try await person.save(on: db)

            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Maine"
            jurisdiction.code = "ME"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let credential = Credential()
            credential.$person.id = person.id!
            credential.$jurisdiction.id = jurisdiction.id!
            credential.licenseNumber = "ME-999"
            try await credential.save(on: db)

            // Delete person - should fail due to foreign key constraint
            // SQLite enforces foreign key constraints, preventing orphaned credentials
            await #expect(throws: (any Error).self) {
                try await person.delete(on: db)
            }

            // Verify person still exists (delete was prevented)
            let foundPerson = try await Person.query(on: db)
                .filter(\.$id == person.id!)
                .first()
            #expect(foundPerson != nil)

            // Credential should still exist
            let foundCredential = try await Credential.query(on: db)
                .filter(\.$id == credential.id!)
                .first()
            #expect(foundCredential != nil)
        }
    }
}

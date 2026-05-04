import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Credential Database Operations")
struct CredentialTests {

    @Test("Credential can be created with valid data")
    func testCreateCredential() async throws {
        try await withDatabase { db in
            // Create person
            let person = Person()
            person.email = "lawyer@example.com"
            person.name = "Licensed Lawyer"
            try await person.save(on: db)

            // Create jurisdiction
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            // Create credential
            let credential = Credential()
            credential.$person.id = person.id!
            credential.$jurisdiction.id = jurisdiction.id!
            credential.licenseNumber = "12345"

            try await credential.save(on: db)

            #expect(credential.id != nil)
            #expect(credential.licenseNumber == "12345")
            #expect(credential.insertedAt != nil)
            #expect(credential.updatedAt != nil)
        }
    }

    @Test("License number must be unique per jurisdiction")
    func testLicenseUniquenessPerJurisdiction() async throws {
        try await withDatabase { db in
            // Create person
            let person = Person()
            person.email = "attorney@example.com"
            person.name = "Attorney"
            try await person.save(on: db)

            // Create jurisdiction
            let nevada = Jurisdiction()
            nevada.name = "Nevada"
            nevada.code = "NV"
            nevada.jurisdictionType = .state
            try await nevada.save(on: db)

            // Create first credential
            let credential1 = Credential()
            credential1.$person.id = person.id!
            credential1.$jurisdiction.id = nevada.id!
            credential1.licenseNumber = "UNIQUE-123"
            try await credential1.save(on: db)

            // Create second person
            let person2 = Person()
            person2.email = "attorney2@example.com"
            person2.name = "Attorney Two"
            try await person2.save(on: db)

            // Attempt to create credential with same license number in same jurisdiction
            let credential2 = Credential()
            credential2.$person.id = person2.id!
            credential2.$jurisdiction.id = nevada.id!
            credential2.licenseNumber = "UNIQUE-123"

            // Expect uniqueness constraint error
            await #expect(throws: Error.self) {
                try await credential2.save(on: db)
            }
        }
    }

    @Test("Same license number allowed in different jurisdictions")
    func testLicenseInDifferentJurisdictions() async throws {
        try await withDatabase { db in
            // Create person
            let person = Person()
            person.email = "multi-state@example.com"
            person.name = "Multi-State Attorney"
            try await person.save(on: db)

            // Create two jurisdictions
            let nevada = Jurisdiction()
            nevada.name = "Nevada"
            nevada.code = "NV"
            nevada.jurisdictionType = .state
            try await nevada.save(on: db)

            let california = Jurisdiction()
            california.name = "California"
            california.code = "CA"
            california.jurisdictionType = .state
            try await california.save(on: db)

            // Create credential in Nevada
            let nvCredential = Credential()
            nvCredential.$person.id = person.id!
            nvCredential.$jurisdiction.id = nevada.id!
            nvCredential.licenseNumber = "12345"
            try await nvCredential.save(on: db)

            // Create credential in California with same number (should succeed)
            let caCredential = Credential()
            caCredential.$person.id = person.id!
            caCredential.$jurisdiction.id = california.id!
            caCredential.licenseNumber = "12345"
            try await caCredential.save(on: db)

            let credentials = try await Credential.query(on: db)
                .filter(\.$person.$id == person.id!)
                .all()

            #expect(credentials.count == 2)
        }
    }

    @Test("Credential requires person reference")
    func testPersonRequired() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Test Jurisdiction"
            jurisdiction.code = "TJ"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let credential = Credential()
            credential.$jurisdiction.id = jurisdiction.id!
            credential.licenseNumber = "NO-PERSON"

            // Expect error when person_id is not set
            await #expect(throws: Error.self) {
                try await credential.save(on: db)
            }
        }
    }

    @Test("Credential requires jurisdiction reference")
    func testJurisdictionRequired() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "no-jurisdiction@example.com"
            person.name = "No Jurisdiction Person"
            try await person.save(on: db)

            let credential = Credential()
            credential.$person.id = person.id!
            credential.licenseNumber = "NO-JURISDICTION"

            // Expect error when jurisdiction_id is not set
            await #expect(throws: Error.self) {
                try await credential.save(on: db)
            }
        }
    }

    @Test("Multiple credentials can be created for same person")
    func testMultipleCredentialsForPerson() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "multi-licensed@example.com"
            person.name = "Multi-Licensed Attorney"
            try await person.save(on: db)

            let nevada = Jurisdiction()
            nevada.name = "Nevada"
            nevada.code = "NV"
            nevada.jurisdictionType = .state
            try await nevada.save(on: db)

            let california = Jurisdiction()
            california.name = "California"
            california.code = "CA"
            california.jurisdictionType = .state
            try await california.save(on: db)

            let washington = Jurisdiction()
            washington.name = "Washington"
            washington.code = "WA"
            washington.jurisdictionType = .state
            try await washington.save(on: db)

            // Create three credentials
            let nvCred = Credential()
            nvCred.$person.id = person.id!
            nvCred.$jurisdiction.id = nevada.id!
            nvCred.licenseNumber = "13400"
            try await nvCred.save(on: db)

            let caCred = Credential()
            caCred.$person.id = person.id!
            caCred.$jurisdiction.id = california.id!
            caCred.licenseNumber = "337252"
            try await caCred.save(on: db)

            let waCred = Credential()
            waCred.$person.id = person.id!
            waCred.$jurisdiction.id = washington.id!
            waCred.licenseNumber = "63446"
            try await waCred.save(on: db)

            let credentials = try await Credential.query(on: db)
                .filter(\.$person.$id == person.id!)
                .all()

            #expect(credentials.count == 3)
        }
    }
}

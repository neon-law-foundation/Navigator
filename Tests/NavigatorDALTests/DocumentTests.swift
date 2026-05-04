import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Document Database Operations")
struct DocumentTests {

    private func makeProject(codename: String, on db: Database) async throws -> Project {
        let project = Project()
        project.codename = codename
        try await project.save(on: db)
        return project
    }

    private func makeBlob(url: String, on db: Database) async throws -> Blob {
        let blob = Blob()
        blob.objectStorageUrl = url
        blob.referencedBy = .documents
        blob.referencedById = UUID()
        try await blob.save(on: db)
        return blob
    }

    @Test("Can create a document and retrieve it by ID")
    func testCreateAndFindByID() async throws {
        try await withDatabase { db in
            let project = try await makeProject(codename: "Peterson", on: db)
            let blob = try await makeBlob(url: "s3://bucket/docs/contract.pdf", on: db)

            let document = Document()
            document.$project.id = project.id!
            document.$blob.id = blob.id!
            document.title = "Retainer Agreement"

            let repo = DocumentRepository(database: db)
            let created = try await repo.create(document: document)
            #expect(created.id != nil)

            let found = try await repo.find(id: created.id!)
            #expect(found != nil)
            #expect(found?.title == "Retainer Agreement")
            #expect(found?.$project.id == project.id)
            #expect(found?.$blob.id == blob.id)
        }
    }

    @Test("Can find all documents for a project")
    func testFindByProject() async throws {
        try await withDatabase { db in
            let project = try await makeProject(codename: "Acme", on: db)
            let blob1 = try await makeBlob(url: "s3://bucket/acme/id.pdf", on: db)
            let blob2 = try await makeBlob(url: "s3://bucket/acme/agreement.pdf", on: db)

            let repo = DocumentRepository(database: db)

            let doc1 = Document()
            doc1.$project.id = project.id!
            doc1.$blob.id = blob1.id!
            doc1.title = "Government ID"
            _ = try await repo.create(document: doc1)

            let doc2 = Document()
            doc2.$project.id = project.id!
            doc2.$blob.id = blob2.id!
            doc2.title = "Signed Agreement"
            _ = try await repo.create(document: doc2)

            let documents = try await repo.findByProject(projectId: project.id!)
            #expect(documents.count == 2)
        }
    }

    @Test("Can eager load project from document")
    func testEagerLoadProject() async throws {
        try await withDatabase { db in
            let project = try await makeProject(codename: "EagerCo", on: db)
            let blob = try await makeBlob(url: "s3://bucket/eager/doc.pdf", on: db)

            let document = Document()
            document.$project.id = project.id!
            document.$blob.id = blob.id!
            document.title = "Test Doc"
            try await document.save(on: db)

            let loaded = try await Document.query(on: db)
                .filter(\.$id == document.id!)
                .with(\.$project)
                .first()

            #expect(loaded?.project.codename == "EagerCo")
        }
    }

    @Test("Can delete a document")
    func testDeleteDocument() async throws {
        try await withDatabase { db in
            let project = try await makeProject(codename: "DeleteCo", on: db)
            let blob = try await makeBlob(url: "s3://bucket/delete/doc.pdf", on: db)

            let document = Document()
            document.$project.id = project.id!
            document.$blob.id = blob.id!
            document.title = "To Be Deleted"

            let repo = DocumentRepository(database: db)
            let created = try await repo.create(document: document)
            let id = created.id!

            try await repo.delete(id: id)

            let found = try await repo.find(id: id)
            #expect(found == nil)
        }
    }

    @Test("Project has documents children relationship")
    func testProjectChildrenDocuments() async throws {
        try await withDatabase { db in
            let project = try await makeProject(codename: "ChildrenCo", on: db)
            let blob = try await makeBlob(url: "s3://bucket/children/doc.pdf", on: db)

            let document = Document()
            document.$project.id = project.id!
            document.$blob.id = blob.id!
            document.title = "Child Doc"
            try await document.save(on: db)

            let loaded = try await Project.query(on: db)
                .filter(\.$id == project.id!)
                .with(\.$documents)
                .first()

            #expect(loaded?.documents.count == 1)
            #expect(loaded?.documents.first?.title == "Child Doc")
        }
    }
}

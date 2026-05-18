import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Document upload + download + delete", .serialized)
struct AdminDocumentsTests {

    /// Encodes a single-file multipart form for a Vapor test request.
    /// Uses a stable boundary so the resulting body is identical across
    /// test runs.
    private func multipartBody(
        title: String,
        filename: String,
        contentType: String,
        fileBytes: String
    ) -> (headers: HTTPHeaders, body: ByteBuffer) {
        let boundary = "----testboundary-\(UUID().uuidString)"
        var body = ""
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"title\"\r\n\r\n"
        body += "\(title)\r\n"
        body += "--\(boundary)\r\n"
        body +=
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
        body += "Content-Type: \(contentType)\r\n\r\n"
        body += "\(fileBytes)\r\n"
        body += "--\(boundary)--\r\n"
        var headers = HTTPHeaders()
        headers.replaceOrAdd(
            name: .contentType,
            value: "multipart/form-data; boundary=\(boundary)"
        )
        return (headers, ByteBuffer(string: body))
    }

    private func seedProject(db: Database) async throws -> Project {
        let p = Project()
        p.codename = "doc-\(UUID().uuidString.prefix(6))"
        try await p.save(on: db)
        return p
    }

    @Test("project show renders an Upload-a-document form")
    func showRendersUploadForm() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(db: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("Upload a document"))
                    #expect(body.contains(#"enctype="multipart/form-data""#))
                    #expect(body.contains(#"type="file""#))
                    #expect(body.contains(#"name="file""#))
                }
            )
        }
    }

    @Test("POST persists Document + Blob and writes the file bytes")
    func postPersistsDocument() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(db: db)
            let (headers, body) = multipartBody(
                title: "Engagement letter",
                filename: "engagement.txt",
                contentType: "text/plain",
                fileBytes: "Hello, signed."
            )
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/documents",
                headers: headers,
                body: body,
                afterResponse: { res async in
                    #expect(
                        res.headers.first(name: .location)
                            == "/admin/projects/\(project.id!.uuidString)"
                    )
                }
            )
            let saved = try await Document.query(on: db)
                .filter(\.$project.$id == project.id!)
                .with(\.$blob)
                .first()
            #expect(saved?.title == "Engagement letter")
            #expect(saved?.blob.referencedBy == .documents)
            #expect(saved?.blob.objectStorageUrl.hasPrefix("file:") == true)
            // The stored bytes should be readable back through the storage.
            let path = app.documentStorage.localPath(for: saved!.blob.objectStorageUrl)
            #expect(path != nil)
            #expect(FileManager.default.fileExists(atPath: path!))
        }
    }

    @Test("POST with missing title redirects with a document_error flash")
    func postRequiresTitle() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(db: db)
            let (headers, body) = multipartBody(
                title: "",
                filename: "anon.txt",
                contentType: "text/plain",
                fileBytes: "x"
            )
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/documents",
                headers: headers,
                body: body,
                afterResponse: { res async in
                    let location = res.headers.first(name: .location) ?? ""
                    #expect(location.contains("document_error="))
                }
            )
            let count = try await Document.query(on: db)
                .filter(\.$project.$id == project.id!)
                .count()
            #expect(count == 0)
        }
    }

    @Test("download streams the persisted bytes back")
    func downloadStreamsBytes() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(db: db)
            let content = "downloadable bytes \(UUID().uuidString)"
            let (headers, body) = multipartBody(
                title: "Brief",
                filename: "brief.txt",
                contentType: "text/plain",
                fileBytes: content
            )
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/documents",
                headers: headers,
                body: body,
                afterResponse: { _ in }
            )
            let doc = try await Document.query(on: db)
                .filter(\.$project.$id == project.id!)
                .first()
            try #require(doc != nil)
            try await app.testing().test(
                .GET,
                "/admin/documents/\(doc!.id!.uuidString)/download",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == content)
                    let disposition = res.headers.first(name: .contentDisposition) ?? ""
                    #expect(disposition.contains(#"filename="Brief""#))
                }
            )
        }
    }

    @Test("DELETE removes the row, the blob, and the file")
    func deleteRemovesAllOfIt() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = try await seedProject(db: db)
            let (headers, body) = multipartBody(
                title: "To delete",
                filename: "del.txt",
                contentType: "text/plain",
                fileBytes: "bye"
            )
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)/documents",
                headers: headers,
                body: body,
                afterResponse: { _ in }
            )
            let doc = try await Document.query(on: db)
                .filter(\.$project.$id == project.id!)
                .with(\.$blob)
                .first()
            try #require(doc != nil)
            let path = app.documentStorage.localPath(for: doc!.blob.objectStorageUrl)
            try await app.testing().test(
                .POST,
                "/admin/documents/\(doc!.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            let gone = try await Document.find(doc!.id!, on: db)
            #expect(gone == nil)
            let blobGone = try await Blob.find(doc!.$blob.id, on: db)
            #expect(blobGone == nil)
            if let path { #expect(!FileManager.default.fileExists(atPath: path)) }
        }
    }
}

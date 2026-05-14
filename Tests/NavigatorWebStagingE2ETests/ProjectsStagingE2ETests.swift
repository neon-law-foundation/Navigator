import AsyncHTTPClient
import Foundation
import Testing

@Suite("Staging E2E: Projects", .serialized)
struct ProjectsStagingE2ETests {

    private static let enabled =
        ProcessInfo.processInfo.environment["STAGING_E2E"] == "1"
    private static let apiBaseURL =
        ProcessInfo.processInfo.environment["STAGING_API_URL"]
        ?? "https://staging.sagebrush.services"

    private func fetchProjectsStatus(token: String?) async throws -> Int {
        let client = HTTPClient.shared
        var request = HTTPClientRequest(url: "\(Self.apiBaseURL)/api/projects")
        if let token {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        let response = try await client.execute(request, timeout: .seconds(30))
        return Int(response.status.code)
    }

    @Test("Admin token returns 200")
    func adminReturns200() async throws {
        guard Self.enabled else { return }
        let token = try #require(
            ProcessInfo.processInfo.environment["COGNITO_ADMIN_TOKEN"]
        )
        #expect(try await fetchProjectsStatus(token: token) == 200)
    }

    @Test("Staff token returns 200")
    func staffReturns200() async throws {
        guard Self.enabled else { return }
        let token = try #require(
            ProcessInfo.processInfo.environment["COGNITO_STAFF_TOKEN"]
        )
        #expect(try await fetchProjectsStatus(token: token) == 200)
    }

    @Test("Client token returns 200")
    func clientReturns200() async throws {
        guard Self.enabled else { return }
        let token = try #require(
            ProcessInfo.processInfo.environment["COGNITO_CLIENT_TOKEN"]
        )
        #expect(try await fetchProjectsStatus(token: token) == 200)
    }

    @Test("No token returns 401")
    func noTokenReturns401() async throws {
        guard Self.enabled else { return }
        #expect(try await fetchProjectsStatus(token: nil) == 401)
    }
}

import AsyncHTTPClient
import Configuration
import Foundation
import Testing

@Suite("Staging E2E: Projects", .serialized)
struct ProjectsStagingE2ETests {

    /// Resolved E2E base URL, or `nil` when this build should skip the suite.
    ///
    /// Reads `APP_ENV` and `API_URL` through `swift-configuration`. Returns
    /// `nil` when `APP_ENV == production` (we never E2E against prod) or
    /// when `API_URL` is unset (local `swift test` runs without staging
    /// credentials).
    private static let apiBaseURL: String? = {
        let reader = ConfigReader(provider: EnvironmentVariablesProvider())
        let appEnv = reader.string(forKey: "app.env", default: "development")
        guard appEnv != "production" else { return nil }
        return reader.string(forKey: "api.url")
    }()

    private func fetchProjectsStatus(baseURL: String, token: String?) async throws -> Int {
        let client = HTTPClient.shared
        var request = HTTPClientRequest(url: "\(baseURL)/api/projects")
        if let token {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        let response = try await client.execute(request, timeout: .seconds(30))
        return Int(response.status.code)
    }

    @Test("Admin token returns 200")
    func adminReturns200() async throws {
        guard let apiBaseURL = Self.apiBaseURL else { return }
        let token = try #require(
            ProcessInfo.processInfo.environment["COGNITO_ADMIN_TOKEN"]
        )
        #expect(try await fetchProjectsStatus(baseURL: apiBaseURL, token: token) == 200)
    }

    @Test("Staff token returns 200")
    func staffReturns200() async throws {
        guard let apiBaseURL = Self.apiBaseURL else { return }
        let token = try #require(
            ProcessInfo.processInfo.environment["COGNITO_STAFF_TOKEN"]
        )
        #expect(try await fetchProjectsStatus(baseURL: apiBaseURL, token: token) == 200)
    }

    @Test("Client token returns 200")
    func clientReturns200() async throws {
        guard let apiBaseURL = Self.apiBaseURL else { return }
        let token = try #require(
            ProcessInfo.processInfo.environment["COGNITO_CLIENT_TOKEN"]
        )
        #expect(try await fetchProjectsStatus(baseURL: apiBaseURL, token: token) == 200)
    }

    @Test("No token returns 401")
    func noTokenReturns401() async throws {
        guard let apiBaseURL = Self.apiBaseURL else { return }
        #expect(try await fetchProjectsStatus(baseURL: apiBaseURL, token: nil) == 401)
    }
}

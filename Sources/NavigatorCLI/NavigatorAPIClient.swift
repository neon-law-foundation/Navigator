import Foundation

public struct Project: Codable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public protocol NavigatorAPIClientProtocol {
    func fetchProjects() async throws -> [Project]
}

public struct NavigatorAPIClient: NavigatorAPIClientProtocol {
    let baseURL: String

    public init(baseURL: String = "https://www.sagebrush.services") {
        self.baseURL = baseURL
    }

    public func fetchProjects() async throws -> [Project] {
        // TODO: Replace mock with actual API call when endpoint is available
        // For now, return empty array as requested
        []

        // Future implementation:
        // let url = URL(string: "\(baseURL)/api/projects")!
        // let (data, _) = try await URLSession.shared.data(from: url)
        // let projects = try JSONDecoder().decode([Project].self, from: data)
        // return projects
    }
}

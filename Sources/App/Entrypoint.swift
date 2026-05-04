import Vapor

/// Entry point for the Neon Law Foundation public website.
///
/// The site is a pure server-rendered Swift/Vapor app. All UI is produced
/// via `NavigatorWeb` Elementary components.
@main
enum Entrypoint {
    static func main() async throws {
        let env = try Environment.detect()
        let app = try await Application.make(env)

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}

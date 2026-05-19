import NavigatorWeb
import Vapor
import VaporElementary

/// Renders chromed error pages for `/admin/*` requests.
///
/// Vapor's default `ErrorMiddleware` returns plain-text bodies for
/// `404` and `5xx`, which feels like the operator has been kicked out
/// of the admin entirely. This middleware sits *inside* the default
/// error middleware: it catches `AbortError`s thrown by route handlers
/// and intercepts `404` responses produced by the trie router for
/// unknown admin paths, replacing both with an `AdminErrorPage` that
/// keeps the sidebar visible and links back to the dashboard.
///
/// Non-admin paths fall through to the default behavior unchanged.
struct AdminErrorMiddleware: AsyncMiddleware {
    let brand: any Brand

    func respond(
        to request: Request,
        chainingTo next: any AsyncResponder
    ) async throws -> Response {
        do {
            let response = try await next.respond(to: request)
            if request.url.path.hasPrefix("/admin"), response.status == .notFound {
                return try await renderErrorPage(
                    request: request,
                    status: .notFound,
                    title: "We couldn't find that resource.",
                    message:
                        "The page you asked for doesn't exist or has been removed. Head back to the dashboard to pick a section."
                )
            }
            return response
        } catch let abort as AbortError where request.url.path.hasPrefix("/admin") {
            return try await renderErrorPage(
                request: request,
                status: abort.status,
                title: Self.title(for: abort.status),
                message: abort.reason
            )
        }
    }

    private func renderErrorPage(
        request: Request,
        status: HTTPResponseStatus,
        title: String,
        message: String
    ) async throws -> Response {
        let html = HTMLResponse {
            AdminErrorPage(
                brand: brand,
                status: Int(status.code),
                title: title,
                message: message
            )
        }
        let response = try await html.encodeResponse(for: request)
        // Preserve the HTTP status that triggered the page — operators
        // and monitors should still see the 404/503 in their logs.
        response.status = status
        return response
    }

    /// Human title to pair with each error status. Falls back to the
    /// status's `reasonPhrase` for codes the admin chrome doesn't
    /// special-case.
    private static func title(for status: HTTPResponseStatus) -> String {
        switch status.code {
        case 400: "That request looked off."
        case 401, 403: "You don't have access to that."
        case 404: "We couldn't find that resource."
        case 409: "That action conflicts with something else."
        case 422: "The form had a problem."
        case 503: "The database is temporarily unavailable."
        default: status.reasonPhrase
        }
    }
}

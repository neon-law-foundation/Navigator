import Vapor

/// Translates `POST` requests carrying a `_method=<VERB>` form field into
/// the verb the form intended.
///
/// HTML `<form>` elements only emit `GET` and `POST`. Admin pages that
/// stage `PATCH`, `PUT`, or `DELETE` actions submit a `POST` with a hidden
/// `_method` input; this responder rewrites the request method so the rest
/// of the routing layer dispatches on the intended verb. Pages emit those
/// hidden inputs through ``FormLayout``, keeping callers free of
/// method-override plumbing.
///
/// ## Why a responder wrap and not `Middleware`
///
/// Vapor's `app.middleware.use(...)` chain runs *inside* `DefaultResponder`
/// — that is, after the trie router has already resolved the route from
/// `request.method`. Rewriting `request.method` in middleware therefore
/// arrives too late to influence routing. To intercept before the lookup,
/// callers wrap the application responder itself via
/// ``Application/useMethodOverride()``.
///
/// ## Honored verbs
///
/// Only `POST` requests are inspected, and only `_method` values in
/// ``allowedOverrides`` (case-insensitive) take effect. `GET`, `POST`, and
/// unknown values leave the method untouched so a hostile payload cannot
/// downgrade a write to a read or coerce a request into a verb this
/// responder is unwilling to honor.
public struct MethodOverrideResponder: AsyncResponder {
    /// HTTP methods callers are allowed to surface through `_method`.
    /// Stored as raw strings because NIO's `HTTPMethod` is not `Hashable`.
    static let allowedOverrides: Set<String> = ["PATCH", "PUT", "DELETE"]

    /// Form field name carrying the intended HTTP method on a `POST`.
    static let fieldName: String = "_method"

    /// The responder that runs after the method has been (optionally)
    /// rewritten. Typically `app.responder.default`.
    let wrapped: any Responder

    public init(wrapping responder: any Responder) {
        self.wrapped = responder
    }

    public func respond(to request: Request) async throws -> Response {
        if request.method == .POST,
            let raw = try? request.content.get(String.self, at: Self.fieldName),
            let override = Self.parse(raw)
        {
            request.method = override
        }
        return try await wrapped.respond(to: request).get()
    }

    /// Maps a `_method` form value to one of the allowed HTTP methods.
    ///
    /// Case-insensitive so templates may emit `_method=delete` if a
    /// designer prefers. Returns `nil` for anything outside
    /// ``allowedOverrides`` — including `GET` and `POST` — so a hostile
    /// payload cannot coerce the request into a verb this responder is
    /// not willing to honor.
    static func parse(_ raw: String) -> HTTPMethod? {
        let upper = raw.uppercased()
        guard allowedOverrides.contains(upper) else { return nil }
        return HTTPMethod(rawValue: upper)
    }
}

extension Application {
    /// Installs ``MethodOverrideResponder`` ahead of the application's
    /// default responder so `POST` requests with `_method=PATCH|PUT|DELETE`
    /// route as that verb.
    ///
    /// Idempotent in spirit — calling twice simply replaces the previously
    /// configured responder. Call this once during configure().
    public func useMethodOverride() {
        responder.use { app in
            MethodOverrideResponder(wrapping: app.responder.default)
        }
    }
}

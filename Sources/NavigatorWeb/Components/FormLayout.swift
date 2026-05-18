import Elementary

/// HTTP verb a form intends to express.
///
/// Browsers only emit `GET` and `POST` from a `<form>`. Selecting `.patch`,
/// `.put`, or `.delete` therefore renders the form as a `POST` plus a
/// hidden `_method` input — ``MethodOverrideResponder`` on the server
/// rewrites the request method back to the intended verb before routing.
public enum FormMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"

    /// The literal `method` attribute the rendered `<form>` carries.
    /// Override verbs collapse to `POST` because browsers will not emit
    /// anything else.
    var formAttribute: HTMLAttribute<HTMLTag.form>.Method {
        switch self {
        case .get: .get
        case .post, .patch, .put, .delete: .post
        }
    }

    /// Whether this verb needs the `_method` override hidden input.
    var requiresOverride: Bool {
        switch self {
        case .get, .post: false
        case .patch, .put, .delete: true
        }
    }
}

/// Form content encoding (`enctype` attribute).
///
/// Defaults are intentionally omitted from the rendered tag so browsers
/// fall back to `application/x-www-form-urlencoded` — the canonical text
/// form encoding. File-upload forms must opt into `.multipart`.
public enum FormEncoding: String, Sendable {
    case urlEncoded = "application/x-www-form-urlencoded"
    case multipart = "multipart/form-data"
}

/// `<form>` wrapper that lets admin pages name any HTTP verb without
/// worrying about how the browser will actually transmit the request.
///
/// `FormLayout` emits the right `method` attribute and, when the chosen
/// verb is `PATCH`, `PUT`, or `DELETE`, a hidden `_method` input that
/// ``MethodOverrideResponder`` rewrites server-side.
///
/// The override input is rendered ahead of the caller's body for
/// readability; the form must not contain a second field named `_method`.
public struct FormLayout<Body: HTML>: HTML {
    public let action: String
    public let method: FormMethod
    public let encoding: FormEncoding
    @HTMLBuilder public let formBody: Body

    public init(
        action: String,
        method: FormMethod,
        encoding: FormEncoding = .urlEncoded,
        @HTMLBuilder body: () -> Body
    ) {
        self.action = action
        self.method = method
        self.encoding = encoding
        self.formBody = body()
    }

    public var body: some HTML {
        // `enctype` is only emitted when it diverges from the browser
        // default so the rendered HTML stays minimal for the common case.
        if encoding == .multipart {
            form(
                .action(action),
                .method(method.formAttribute),
                .custom(name: "enctype", value: encoding.rawValue)
            ) {
                formChildren
            }
        } else {
            form(
                .action(action),
                .method(method.formAttribute)
            ) {
                formChildren
            }
        }
    }

    @HTMLBuilder
    private var formChildren: some HTML {
        if method.requiresOverride {
            input(
                .type(.hidden),
                .name("_method"),
                .value(method.rawValue)
            )
        }
        formBody
    }
}

extension FormLayout: Sendable where Body: Sendable {}

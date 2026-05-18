import Elementary

/// A compact `<form>` that submits a `_method=DELETE` POST when the
/// button is clicked.
///
/// Designed for inline use in admin list rows ("delete this project") so
/// the destructive action stays a real HTML form rather than relying on
/// JavaScript to issue an `XMLHttpRequest`. Pair with
/// ``MethodOverrideResponder`` so the request reaches the routing layer
/// as a real `DELETE`.
///
/// The default `confirmMessage` wires an `onsubmit` confirm() so a stray
/// click cannot silently destroy data; passing an empty string opts out
/// (use it on a dedicated confirmation page where the prompt is already
/// in the page chrome).
public struct ConfirmDeleteForm: HTML, Sendable {
    public let action: String
    public let label: String
    public let confirmMessage: String

    public init(
        action: String,
        label: String = "Delete",
        confirmMessage: String = "Are you sure? This cannot be undone."
    ) {
        self.action = action
        self.label = label
        self.confirmMessage = confirmMessage
    }

    public var body: some HTML {
        FormLayout(action: action, method: .delete) {
            // The confirm() prompt is wired through `onsubmit` so the
            // delete is gated on a yes/no even without any JavaScript
            // shipped by the page itself — every browser ships the
            // built-in dialog.
            button(
                .type(.submit),
                .class(ButtonVariant.danger.classes)
            ) { label }
            .attributes(
                .custom(
                    name: "onsubmit",
                    value: "return confirm('\(escapedConfirmMessage)')"
                ),
                when: !confirmMessage.isEmpty
            )
        }
    }

    /// Escapes the confirm message so embedded apostrophes do not break
    /// the surrounding `onsubmit="…"` attribute. The full escape rules
    /// for an HTML attribute value run through `&apos;`, but Safari and
    /// every other browser accept the entity form, so we lean on it
    /// rather than minting a different escape table.
    private var escapedConfirmMessage: String {
        confirmMessage.replacingOccurrences(of: "'", with: "&apos;")
    }
}

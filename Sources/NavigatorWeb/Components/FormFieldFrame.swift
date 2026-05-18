import Elementary

/// Shared label + help-text + error layout for ``TextField``, ``TextArea``,
/// ``SelectField``, and other admin form rows.
///
/// The row owns the visual chrome — the wrapping `<div>`, the `<label>`,
/// help text, and the error message — so the individual field components
/// only have to render the input element itself. Centralizing the markup
/// here keeps spacing and accessibility (label-for-id, `role=alert`)
/// consistent across the entire form surface.
struct FormFieldRow<Body: HTML>: HTML {
    let id: String
    let label: String
    let helpText: String?
    let error: String?
    @HTMLBuilder let content: Body

    init(
        id: String,
        label: String,
        helpText: String? = nil,
        error: String? = nil,
        @HTMLBuilder content: () -> Body
    ) {
        self.id = id
        self.label = label
        self.helpText = helpText
        self.error = error
        self.content = content()
    }

    var body: some HTML {
        div(.class("mb-4")) {
            Elementary.label(
                .for(id),
                .class("block text-sm font-medium text-gray-700 mb-1")
            ) { label }
            content
            if let helpText {
                p(.class("mt-1 text-xs text-gray-500")) { helpText }
            }
            if let error {
                p(
                    .class("mt-1 text-xs text-red-600"),
                    .custom(name: "role", value: "alert")
                ) { error }
            }
        }
    }
}

/// Namespace for helpers shared across the form field components — most
/// importantly the deterministic id used to bind labels to inputs and
/// the Tailwind class string for input chrome. Kept as an enum so it
/// cannot be instantiated and the static members read like a namespace
/// at call sites.
enum FormField {

    /// Deterministic DOM id for a given field name so labels and inputs
    /// can stay linked without callers having to thread an id through.
    static func id(for name: String) -> String { "field-\(name)" }

    /// Standard Tailwind class string for a form input. The red border
    /// when `hasError` is true is the visual half of the `role=alert`
    /// message below the input.
    static func inputClass(hasError: Bool) -> String {
        let base =
            "block w-full rounded-md border px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2"
        let palette =
            hasError
            ? "border-red-400 focus:ring-red-300"
            : "border-gray-300 focus:ring-indigo-300"
        return "\(base) \(palette)"
    }
}

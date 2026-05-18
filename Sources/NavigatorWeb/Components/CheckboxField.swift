import Elementary

/// A labeled `<input type="checkbox">` row.
///
/// HTML omits the field name from the submitted form body when a checkbox
/// is unchecked, so the server-side decoder must treat absence as `false`.
/// The `value` parameter controls what string the server receives when the
/// box is checked (defaults to `"true"`).
public struct CheckboxField: HTML, Sendable {
    public let name: String
    public let label: String
    public let checked: Bool
    public let value: String
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        checked: Bool = false,
        value: String = "true",
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.checked = checked
        self.value = value
        self.helpText = helpText
        self.error = error
    }

    public var body: some HTML {
        let id = FormField.id(for: name)
        // Checkboxes inline the label after the input rather than above
        // it, so they intentionally do not reuse `FormFieldRow`.
        div(.class("mb-4")) {
            div(.class("flex items-center gap-2")) {
                input(
                    .id(id),
                    .type(.checkbox),
                    .name(name),
                    .value(value)
                )
                .attributes(.checked, when: checked)
                Elementary.label(
                    .for(id),
                    .class("text-sm text-gray-700")
                ) { label }
            }
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

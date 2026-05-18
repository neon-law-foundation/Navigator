import Elementary

/// A labeled `<textarea>` row.
///
/// Mirrors ``TextField`` but renders a multi-line input. The text content
/// of the `<textarea>` carries the value — the `value` attribute used by
/// `<input>` does not apply.
public struct TextArea: HTML, Sendable {
    public let name: String
    public let label: String
    public let value: String?
    public let rows: Int
    public let required: Bool
    public let placeholder: String?
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        value: String? = nil,
        rows: Int = 4,
        required: Bool = false,
        placeholder: String? = nil,
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.value = value
        self.rows = rows
        self.required = required
        self.placeholder = placeholder
        self.helpText = helpText
        self.error = error
    }

    public var body: some HTML {
        let id = FormField.id(for: name)
        FormFieldRow(
            id: id,
            label: label,
            helpText: helpText,
            error: error
        ) {
            textarea(
                .id(id),
                .name(name),
                .custom(name: "rows", value: String(rows)),
                .class(FormField.inputClass(hasError: error != nil))
            ) {
                value ?? ""
            }
            .attributes(.required, when: required)
            .attributes(
                .custom(name: "placeholder", value: placeholder ?? ""),
                when: placeholder != nil
            )
        }
    }
}

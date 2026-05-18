import Elementary

/// One row in a ``SelectField`` dropdown.
public struct SelectOption: Sendable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

/// A labeled `<select>` dropdown row.
///
/// Options are plain `(value, label)` pairs at this level — the
/// convenience init for `CaseIterable & RawRepresentable<String>` enums
/// builds the array from any DAL enum (`ProjectStatus`, `ProjectRole`,
/// `RetainerStatus`, …) so admin forms never have to hand-assemble the
/// option list.
///
/// `includeBlank` prepends an empty-string option so the field can
/// represent "no value chosen yet" — the only way HTML lets a `<select>`
/// surface a nil selection.
public struct SelectField: HTML, Sendable {
    public let name: String
    public let label: String
    public let options: [SelectOption]
    public let selected: String?
    public let required: Bool
    public let includeBlank: Bool
    public let blankLabel: String
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        options: [SelectOption],
        selected: String? = nil,
        required: Bool = false,
        includeBlank: Bool = false,
        blankLabel: String = "",
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.options = options
        self.selected = selected
        self.required = required
        self.includeBlank = includeBlank
        self.blankLabel = blankLabel
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
            select(
                .id(id),
                .name(name),
                .class(FormField.inputClass(hasError: error != nil))
            ) {
                if includeBlank {
                    option(.value("")) { blankLabel }
                }
                for choice in options {
                    option(.value(choice.value)) {
                        choice.label
                    }
                    .attributes(.selected, when: choice.value == selected)
                }
            }
            .attributes(.required, when: required)
        }
    }
}

extension SelectField {
    /// Build a select from any `CaseIterable & RawRepresentable<String>`
    /// enum. Each case becomes an option whose `value` is the raw value
    /// and whose label is the case name with the first letter
    /// upper-cased — matching Swift's enum-case spelling rules.
    public init<E: CaseIterable & RawRepresentable>(
        _ type: E.Type,
        name: String,
        label: String,
        selected: E? = nil,
        required: Bool = false,
        includeBlank: Bool = false,
        blankLabel: String = "",
        helpText: String? = nil,
        error: String? = nil
    ) where E.RawValue == String {
        let opts = E.allCases.map { value -> SelectOption in
            SelectOption(value: value.rawValue, label: Self.titlecase(value.rawValue))
        }
        self.init(
            name: name,
            label: label,
            options: opts,
            selected: selected?.rawValue,
            required: required,
            includeBlank: includeBlank,
            blankLabel: blankLabel,
            helpText: helpText,
            error: error
        )
    }

    /// Upper-cases the first character of the raw value. Enum cases in
    /// Swift are lowerCamelCase by convention so this is enough to
    /// produce a human-readable label for the common case; callers that
    /// want richer labels (`"Pending signature"` from `pendingSignature`)
    /// should supply the option array directly.
    private static func titlecase(_ raw: String) -> String {
        guard let first = raw.first else { return raw }
        return first.uppercased() + raw.dropFirst()
    }
}

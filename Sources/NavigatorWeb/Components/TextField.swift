import Elementary

/// A labeled single-line `<input>` row.
///
/// `TextField` renders the four pieces every admin form row needs: a
/// label bound to the input by id, the input itself, optional help text,
/// and an optional error message. The `inputType` parameter selects the
/// browser's input variant (text, email, url, date, etc.) so a single
/// component covers every text-shaped field while ``EmailField``,
/// ``URLField``, and ``DateField`` provide named convenience wrappers
/// for the cases admin pages reach for repeatedly.
///
/// The label / input pair uses a deterministic `field-<name>` id so a
/// screen reader can announce the label when focus enters the input and
/// the rendered HTML stays trivial to assert in tests.
public struct TextField: HTML, Sendable {
    public let name: String
    public let label: String
    public let value: String?
    public let inputType: HTMLAttribute<HTMLTag.input>.InputType
    public let required: Bool
    public let placeholder: String?
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        value: String? = nil,
        inputType: HTMLAttribute<HTMLTag.input>.InputType = .text,
        required: Bool = false,
        placeholder: String? = nil,
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.value = value
        self.inputType = inputType
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
            input(
                .id(id),
                .name(name),
                .type(inputType),
                .class(FormField.inputClass(hasError: error != nil))
            )
            .attributes(.value(value ?? ""), when: value != nil)
            .attributes(.required, when: required)
            .attributes(
                .custom(name: "placeholder", value: placeholder ?? ""),
                when: placeholder != nil
            )
        }
    }
}

/// `<input type="email">` wrapper. Same parameters as ``TextField`` minus
/// `inputType`.
public struct EmailField: HTML, Sendable {
    public let name: String
    public let label: String
    public let value: String?
    public let required: Bool
    public let placeholder: String?
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        value: String? = nil,
        required: Bool = false,
        placeholder: String? = nil,
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.value = value
        self.required = required
        self.placeholder = placeholder
        self.helpText = helpText
        self.error = error
    }

    public var body: some HTML {
        TextField(
            name: name,
            label: label,
            value: value,
            inputType: .email,
            required: required,
            placeholder: placeholder,
            helpText: helpText,
            error: error
        )
    }
}

/// `<input type="url">` wrapper.
public struct URLField: HTML, Sendable {
    public let name: String
    public let label: String
    public let value: String?
    public let required: Bool
    public let placeholder: String?
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        value: String? = nil,
        required: Bool = false,
        placeholder: String? = nil,
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.value = value
        self.required = required
        self.placeholder = placeholder
        self.helpText = helpText
        self.error = error
    }

    public var body: some HTML {
        TextField(
            name: name,
            label: label,
            value: value,
            inputType: .url,
            required: required,
            placeholder: placeholder,
            helpText: helpText,
            error: error
        )
    }
}

/// `<input type="date">` wrapper. The browser's date picker renders the
/// value as `YYYY-MM-DD`; callers must format `Date` values themselves.
public struct DateField: HTML, Sendable {
    public let name: String
    public let label: String
    public let value: String?
    public let required: Bool
    public let helpText: String?
    public let error: String?

    public init(
        name: String,
        label: String,
        value: String? = nil,
        required: Bool = false,
        helpText: String? = nil,
        error: String? = nil
    ) {
        self.name = name
        self.label = label
        self.value = value
        self.required = required
        self.helpText = helpText
        self.error = error
    }

    public var body: some HTML {
        TextField(
            name: name,
            label: label,
            value: value,
            inputType: .date,
            required: required,
            helpText: helpText,
            error: error
        )
    }
}

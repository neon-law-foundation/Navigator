import Testing

@testable import NavigatorWeb

/// `SelectField` renders a `<select>` row with a label, an optional blank
/// option, and per-option `selected` highlighting. A convenience init
/// builds the option list from any `CaseIterable & RawRepresentable<String>`
/// enum so admin forms backed by enums like `ProjectStatus` or
/// `ProjectRole` do not have to assemble the option array themselves.
@Suite("SelectField")
struct SelectFieldTests {

    /// Fixture enum used so the tests do not depend on the real DAL
    /// enums shifting their cases or raw values.
    fileprivate enum Color: String, CaseIterable {
        case red
        case green
        case blue
    }

    @Test("renders a <select> with the given name and bound label")
    func basic() {
        let html = SelectField(
            name: "status",
            label: "Status",
            options: [
                SelectOption(value: "active", label: "Active"),
                SelectOption(value: "closed", label: "Closed"),
            ]
        ).render()

        #expect(html.contains("<select"))
        #expect(html.contains(#"name="status""#))
        #expect(html.contains(#"id="field-status""#))
        #expect(html.contains(#"for="field-status""#))
        #expect(html.contains(">Status<"))
    }

    @Test("renders one <option> per supplied SelectOption")
    func optionsRender() {
        let html = SelectField(
            name: "color",
            label: "Color",
            options: [
                SelectOption(value: "red", label: "Red"),
                SelectOption(value: "green", label: "Green"),
                SelectOption(value: "blue", label: "Blue"),
            ]
        ).render()

        #expect(html.contains(#"value="red""#))
        #expect(html.contains(">Red<"))
        #expect(html.contains(#"value="green""#))
        #expect(html.contains(">Green<"))
        #expect(html.contains(#"value="blue""#))
        #expect(html.contains(">Blue<"))
    }

    @Test("the selected option carries the selected attribute")
    func selectedOption() {
        let html = SelectField(
            name: "color",
            label: "Color",
            options: [
                SelectOption(value: "red", label: "Red"),
                SelectOption(value: "green", label: "Green"),
            ],
            selected: "green"
        ).render()

        // Selected option emits `selected` after its value attribute.
        #expect(html.contains(#"<option value="green" selected"#))
        // Unselected option must not carry the attribute.
        #expect(!html.contains(#"<option value="red" selected"#))
    }

    @Test("no option carries the selected attribute when selected is nil")
    func noSelection() {
        let html = SelectField(
            name: "x",
            label: "X",
            options: [SelectOption(value: "a", label: "A")],
            selected: nil
        ).render()

        #expect(!html.contains("selected"))
    }

    @Test("required adds the required attribute")
    func required() {
        let html = SelectField(
            name: "x",
            label: "X",
            options: [SelectOption(value: "a", label: "A")],
            required: true
        ).render()

        #expect(html.contains("required"))
    }

    @Test("includeBlank prepends a blank option with the supplied label")
    func includeBlank() {
        let html = SelectField(
            name: "color",
            label: "Color",
            options: [SelectOption(value: "red", label: "Red")],
            includeBlank: true,
            blankLabel: "Pick one\u{2026}"
        ).render()

        #expect(html.contains(#"<option value="""#))
        #expect(html.contains("Pick one\u{2026}"))
    }

    @Test("error message renders with role=alert")
    func error() {
        let html = SelectField(
            name: "x",
            label: "X",
            options: [SelectOption(value: "a", label: "A")],
            error: "Pick a value"
        ).render()

        #expect(html.contains("Pick a value"))
        #expect(html.contains(#"role="alert""#))
    }

    @Test("convenience init from a CaseIterable RawRepresentable enum")
    func enumConvenienceInit() {
        let html = SelectField(
            Color.self,
            name: "color",
            label: "Color",
            selected: .green
        ).render()

        #expect(html.contains(#"value="red""#))
        #expect(html.contains(#"value="green""#))
        #expect(html.contains(#"value="blue""#))
        #expect(html.contains(#"<option value="green" selected"#))
    }

    @Test("enum convenience init titlecases case names by default")
    func enumConvenienceLabels() {
        let html = SelectField(
            Color.self,
            name: "color",
            label: "Color"
        ).render()

        #expect(html.contains(">Red<"))
        #expect(html.contains(">Green<"))
        #expect(html.contains(">Blue<"))
    }
}

@Suite("CheckboxField")
struct CheckboxFieldTests {

    @Test("renders type=checkbox with the field name")
    func basic() {
        let html = CheckboxField(name: "active", label: "Active").render()
        #expect(html.contains(#"type="checkbox""#))
        #expect(html.contains(#"name="active""#))
        #expect(html.contains(">Active<"))
    }

    @Test("checked=true emits the checked attribute")
    func checked() {
        let html = CheckboxField(name: "x", label: "X", checked: true).render()
        #expect(html.contains("checked"))
    }

    @Test("checked=false omits the checked attribute")
    func unchecked() {
        let html = CheckboxField(name: "x", label: "X", checked: false).render()
        #expect(!html.contains("checked"))
    }

    @Test("default value attribute is \"true\"")
    func defaultValue() {
        let html = CheckboxField(name: "x", label: "X").render()
        #expect(html.contains(#"value="true""#))
    }

    @Test("custom value is honored")
    func customValue() {
        let html = CheckboxField(name: "role", label: "Role", value: "admin").render()
        #expect(html.contains(#"value="admin""#))
    }

    @Test("error message renders with role=alert")
    func errorRendered() {
        let html = CheckboxField(name: "x", label: "X", error: "Required").render()
        #expect(html.contains("Required"))
        #expect(html.contains(#"role="alert""#))
    }
}

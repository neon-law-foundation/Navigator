import Testing

@testable import NavigatorWeb

/// `TextField` and its typed variants (`EmailField`, `URLField`,
/// `DateField`) wrap an `<input>` with the label, value, required flag,
/// help text, and error message admin pages need on every form row.
@Suite("TextField")
struct TextFieldTests {

    @Test("renders a label bound to the input via for/id")
    func labelBoundToInput() {
        let html = TextField(name: "codename", label: "Codename").render()
        #expect(html.contains(#"<label"#))
        #expect(html.contains(#"for="field-codename""#))
        #expect(html.contains(#"id="field-codename""#))
        #expect(html.contains(">Codename<"))
    }

    @Test("renders an input with name set from the field name")
    func inputName() {
        let html = TextField(name: "codename", label: "Codename").render()
        #expect(html.contains(#"name="codename""#))
        // Default input type is text.
        #expect(html.contains(#"type="text""#))
    }

    @Test("value attribute is omitted when value is nil")
    func valueOmittedWhenNil() {
        let html = TextField(name: "x", label: "X", value: nil).render()
        #expect(!html.contains(#"value=""#))
    }

    @Test("value attribute is emitted when value is supplied")
    func valueEmittedWhenPresent() {
        let html = TextField(name: "x", label: "X", value: "Alpha").render()
        #expect(html.contains(#"value="Alpha""#))
    }

    @Test("required flag emits the HTML required attribute")
    func requiredFlag() {
        let html = TextField(name: "x", label: "X", required: true).render()
        #expect(html.contains("required"))
    }

    @Test("placeholder is rendered when supplied")
    func placeholder() {
        let html = TextField(name: "x", label: "X", placeholder: "Type here").render()
        #expect(html.contains(#"placeholder="Type here""#))
    }

    @Test("help text is rendered below the input")
    func helpText() {
        let html = TextField(name: "x", label: "X", helpText: "Lowercase letters only").render()
        #expect(html.contains("Lowercase letters only"))
    }

    @Test("error message is rendered when supplied")
    func errorRendered() {
        let html = TextField(name: "x", label: "X", error: "Must be unique").render()
        #expect(html.contains("Must be unique"))
    }

    @Test("no error markup when error is nil")
    func errorOmittedWhenNil() {
        let html = TextField(name: "x", label: "X").render()
        #expect(!html.contains(#"role="alert""#))
    }

    @Test("error markup carries role=alert for screen readers")
    func errorHasRoleAlert() {
        let html = TextField(name: "x", label: "X", error: "Required").render()
        #expect(html.contains(#"role="alert""#))
    }

    @Test("EmailField forces type=email")
    func emailField() {
        let html = EmailField(name: "email", label: "Email").render()
        #expect(html.contains(#"type="email""#))
    }

    @Test("URLField forces type=url")
    func urlField() {
        let html = URLField(name: "homepage", label: "Homepage").render()
        #expect(html.contains(#"type="url""#))
    }

    @Test("DateField forces type=date")
    func dateField() {
        let html = DateField(name: "starts_at", label: "Starts at").render()
        #expect(html.contains(#"type="date""#))
    }
}

@Suite("TextArea")
struct TextAreaTests {

    @Test("renders a <textarea> with the field name")
    func basic() {
        let html = TextArea(name: "notes", label: "Notes").render()
        #expect(html.contains("<textarea"))
        #expect(html.contains(#"name="notes""#))
        #expect(html.contains(">Notes<"))
    }

    @Test("value is rendered as the textarea's text content")
    func valueAsContent() {
        let html = TextArea(name: "notes", label: "Notes", value: "Hello world").render()
        #expect(html.contains("Hello world"))
        // <textarea> uses inner text, not a value attribute.
        #expect(!html.contains(#"value="Hello world""#))
    }

    @Test("rows attribute defaults to 4 and is honored when overridden")
    func rowsAttribute() {
        let defaultHTML = TextArea(name: "x", label: "X").render()
        #expect(defaultHTML.contains(#"rows="4""#))
        let customHTML = TextArea(name: "x", label: "X", rows: 10).render()
        #expect(customHTML.contains(#"rows="10""#))
    }

    @Test("required flag emits the required attribute")
    func requiredFlag() {
        let html = TextArea(name: "x", label: "X", required: true).render()
        #expect(html.contains("required"))
    }

    @Test("error message is rendered when supplied")
    func errorRendered() {
        let html = TextArea(name: "x", label: "X", error: "Too long").render()
        #expect(html.contains("Too long"))
        #expect(html.contains(#"role="alert""#))
    }
}

@Suite("HiddenField")
struct HiddenFieldTests {

    @Test("renders <input type=\"hidden\"> with name and value")
    func renders() {
        let html = HiddenField(name: "csrf_token", value: "abc123").render()
        #expect(html.contains(#"type="hidden""#))
        #expect(html.contains(#"name="csrf_token""#))
        #expect(html.contains(#"value="abc123""#))
    }

    @Test("does not render a label")
    func noLabel() {
        let html = HiddenField(name: "x", value: "y").render()
        #expect(!html.contains("<label"))
    }
}

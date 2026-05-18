import Testing

@testable import NavigatorWeb

/// `SubmitButton`, `LinkButton`, `FormErrors`, and `ConfirmDeleteForm`
/// round out the form helpers. Buttons share a variant palette so a
/// "Save / Cancel" pair on any admin form reads with consistent
/// emphasis; `FormErrors` renders a top-of-form summary; and
/// `ConfirmDeleteForm` packages the `_method=DELETE` pattern into a
/// single drop-in element.
@Suite("SubmitButton")
struct SubmitButtonTests {

    @Test("renders <button type=\"submit\"> with the label")
    func basic() {
        let html = SubmitButton("Save").render()
        #expect(html.contains("<button"))
        #expect(html.contains(#"type="submit""#))
        #expect(html.contains(">Save<"))
    }

    @Test("primary variant uses indigo background")
    func primaryVariant() {
        let html = SubmitButton("Save", variant: .primary).render()
        #expect(html.contains("bg-indigo"))
    }

    @Test("secondary variant uses gray background")
    func secondaryVariant() {
        let html = SubmitButton("Cancel", variant: .secondary).render()
        #expect(html.contains("bg-gray"))
    }

    @Test("danger variant uses red background")
    func dangerVariant() {
        let html = SubmitButton("Delete", variant: .danger).render()
        #expect(html.contains("bg-red"))
    }
}

@Suite("LinkButton")
struct LinkButtonTests {

    @Test("renders an <a> with the href and label")
    func basic() {
        let html = LinkButton("Cancel", href: "/admin/projects").render()
        #expect(html.contains("<a "))
        #expect(html.contains(#"href="/admin/projects""#))
        #expect(html.contains(">Cancel<"))
    }

    @Test("defaults to secondary variant styling")
    func defaultVariantIsSecondary() {
        let html = LinkButton("Back", href: "/x").render()
        #expect(html.contains("bg-gray"))
    }

    @Test("primary variant applies primary styling")
    func primaryVariant() {
        let html = LinkButton("New project", href: "/x", variant: .primary).render()
        #expect(html.contains("bg-indigo"))
    }
}

@Suite("FormErrors")
struct FormErrorsTests {

    @Test("renders nothing when the message list is empty")
    func emptyList() {
        let html = FormErrors([]).render()
        #expect(!html.contains("role=\"alert\""))
        #expect(!html.contains("<ul"))
    }

    @Test("renders one alert summary with the messages as a list")
    func nonEmptyList() {
        let html = FormErrors(["Codename is required", "Status is invalid"]).render()
        #expect(html.contains(#"role="alert""#))
        #expect(html.contains("Codename is required"))
        #expect(html.contains("Status is invalid"))
    }

    @Test("single-error list still renders the alert chrome")
    func singleError() {
        let html = FormErrors(["Codename is required"]).render()
        #expect(html.contains(#"role="alert""#))
        #expect(html.contains("Codename is required"))
    }
}

@Suite("ConfirmDeleteForm")
struct ConfirmDeleteFormTests {

    @Test("renders a POST form with the _method=DELETE hidden input")
    func renders() {
        let html = ConfirmDeleteForm(action: "/admin/projects/abc").render()
        #expect(html.contains(#"action="/admin/projects/abc""#))
        #expect(html.contains(#"method="post""#))
        #expect(html.contains(#"name="_method""#))
        #expect(html.contains(#"value="DELETE""#))
    }

    @Test("button defaults to a Delete label")
    func defaultLabel() {
        let html = ConfirmDeleteForm(action: "/x").render()
        #expect(html.contains(">Delete<"))
    }

    @Test("custom button label is honored")
    func customLabel() {
        let html = ConfirmDeleteForm(action: "/x", label: "Archive project").render()
        #expect(html.contains(">Archive project<"))
    }

    @Test("default confirm prompt is included via onsubmit")
    func defaultConfirmAttached() {
        let html = ConfirmDeleteForm(action: "/x").render()
        #expect(html.contains("onsubmit"))
        #expect(html.contains("confirm("))
    }

    @Test("explicit empty confirm prompt disables the inline confirm")
    func confirmMessageDisabled() {
        let html = ConfirmDeleteForm(action: "/x", confirmMessage: "").render()
        #expect(!html.contains("onsubmit"))
    }
}

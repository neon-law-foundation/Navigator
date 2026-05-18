import Elementary
import Testing

@testable import NavigatorWeb

/// `FormLayout` wraps `<form>` so callers can name any HTTP verb. Verbs
/// browsers refuse to emit natively (`PATCH`, `PUT`, `DELETE`) are
/// rewritten to `POST` with a hidden `_method` input — paired with
/// ``MethodOverrideResponder`` on the server side.
@Suite("FormLayout")
struct FormLayoutTests {

    @Test("GET form emits method=\"get\" with no _method override input")
    func getForm() {
        let html = FormLayout(action: "/admin/projects", method: .get) {
            input(.type(.text), .name("q"))
        }.render()

        #expect(html.contains(#"<form"#))
        #expect(html.contains(#"action="/admin/projects""#))
        #expect(html.contains(#"method="get""#))
        #expect(!html.contains(#"name="_method""#))
    }

    @Test("POST form emits method=\"post\" with no override input")
    func postForm() {
        let html = FormLayout(action: "/admin/projects", method: .post) {
            input(.type(.text), .name("codename"))
        }.render()

        #expect(html.contains(#"action="/admin/projects""#))
        #expect(html.contains(#"method="post""#))
        #expect(!html.contains(#"name="_method""#))
    }

    @Test("PATCH form emits method=\"post\" plus _method=\"PATCH\" hidden input")
    func patchForm() {
        let html = FormLayout(action: "/admin/projects/abc", method: .patch) {
            input(.type(.text), .name("title"))
        }.render()

        #expect(html.contains(#"method="post""#))
        #expect(html.contains(#"name="_method""#))
        #expect(html.contains(#"value="PATCH""#))
        #expect(html.contains(#"type="hidden""#))
    }

    @Test("PUT form emits _method=\"PUT\"")
    func putForm() {
        let html = FormLayout(action: "/admin/projects/abc", method: .put) {
            input(.type(.text), .name("title"))
        }.render()

        #expect(html.contains(#"method="post""#))
        #expect(html.contains(#"value="PUT""#))
    }

    @Test("DELETE form emits _method=\"DELETE\"")
    func deleteForm() {
        let html = FormLayout(action: "/admin/projects/abc", method: .delete) {
        }.render()

        #expect(html.contains(#"method="post""#))
        #expect(html.contains(#"value="DELETE""#))
    }

    @Test("default encoding omits enctype so browsers default to urlencoded")
    func defaultEncoding() {
        let html = FormLayout(action: "/x", method: .post) {}.render()
        #expect(!html.contains("enctype"))
    }

    @Test("multipart encoding sets enctype=\"multipart/form-data\"")
    func multipartEncoding() {
        let html = FormLayout(
            action: "/x",
            method: .post,
            encoding: .multipart
        ) {}.render()

        #expect(html.contains(#"enctype="multipart/form-data""#))
    }

    @Test("body content is rendered inside the form")
    func bodyContent() {
        let html = FormLayout(action: "/x", method: .post) {
            input(.type(.text), .name("name"), .value("Alpha"))
        }.render()

        #expect(html.contains(#"name="name""#))
        #expect(html.contains(#"value="Alpha""#))
    }

    @Test("the hidden _method input is rendered before any caller-supplied content")
    func overrideInputPosition() {
        let html = FormLayout(action: "/x", method: .delete) {
            input(.type(.text), .name("confirm"), .value("yes"))
        }.render()

        guard
            let methodRange = html.range(of: #"name="_method""#),
            let confirmRange = html.range(of: #"name="confirm""#)
        else {
            Issue.record("Expected both inputs to render")
            return
        }
        // The override hint must sit ahead of caller content so a stray
        // duplicate `name="_method"` from the body cannot shadow it via
        // form-encoded last-value-wins semantics.
        #expect(methodRange.lowerBound < confirmRange.lowerBound)
    }
}

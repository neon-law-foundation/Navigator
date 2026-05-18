import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/mailroom/letters/new` — admin compose form for a new physical
/// mail record. The list of letters still lives at `/admin/mailroom`
/// (the public mail-room view); this page only handles authoring.
struct AdminLetterFormPage: HTML {
    let brand: any Brand
    let mailrooms: [Mailroom]
    let form: LetterFormValues
    let errors: LetterFormErrors

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "New letter",
            activeSection: .mailroom,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: "/admin/mailroom/letters", method: .post) {
                    SelectField(
                        name: "mailroomId",
                        label: "Mailroom",
                        options: mailrooms.map {
                            SelectOption(value: $0.id?.uuidString ?? "", label: $0.name)
                        },
                        selected: form.mailroomId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick a mailroom\u{2026}",
                        error: errors.mailroomId
                    )
                    TextField(
                        name: "mailboxNumber",
                        label: "Mailbox number",
                        value: form.mailboxNumber,
                        helpText: "Optional. Must be an integer if supplied.",
                        error: errors.mailboxNumber
                    )
                    TextField(
                        name: "sender",
                        label: "Sender",
                        value: form.sender,
                        error: errors.sender
                    )
                    TextField(
                        name: "subject",
                        label: "Subject",
                        value: form.subject,
                        error: errors.subject
                    )
                    DateField(
                        name: "receivedAt",
                        label: "Received",
                        value: form.receivedAt,
                        helpText: "Calendar date the letter arrived.",
                        error: errors.receivedAt
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton("Create letter", variant: .primary)
                        LinkButton("Cancel", href: "/admin/mailroom")
                    }
                }
            }
        }
    }
}

struct LetterFormValues: Sendable {
    let mailroomId: String
    let mailboxNumber: String
    let sender: String
    let subject: String
    let receivedAt: String

    init(
        mailroomId: String = "",
        mailboxNumber: String = "",
        sender: String = "",
        subject: String = "",
        receivedAt: String = ""
    ) {
        self.mailroomId = mailroomId
        self.mailboxNumber = mailboxNumber
        self.sender = sender
        self.subject = subject
        self.receivedAt = receivedAt
    }
}

struct LetterFormErrors: Sendable {
    let mailroomId: String?
    let mailboxNumber: String?
    let sender: String?
    let subject: String?
    let receivedAt: String?
    let summary: [String]

    init(
        mailroomId: String? = nil,
        mailboxNumber: String? = nil,
        sender: String? = nil,
        subject: String? = nil,
        receivedAt: String? = nil,
        summary: [String] = []
    ) {
        self.mailroomId = mailroomId
        self.mailboxNumber = mailboxNumber
        self.sender = sender
        self.subject = subject
        self.receivedAt = receivedAt
        self.summary = summary
    }

    static let none = LetterFormErrors()
}

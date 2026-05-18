import Elementary
import NavigatorDAL
import NavigatorWeb

struct QuestionsIndexPage: HTML {
    let brand: any Brand
    let questions: [Question]
    let flash: String?

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Questions",
            activeSection: .questions,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(questions.count) question\(questions.count == 1 ? "" : "s")"
                }
                LinkButton("New question", href: "/admin/questions/new", variant: .primary)
            }
            AdminFlashBanner(message: flash)
            if questions.isEmpty {
                AdminEmptyState(
                    message: "No questions yet. ",
                    ctaHref: "/admin/questions/new",
                    ctaLabel: "Create the first one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Code")
                                AdminTableHeader("Prompt")
                                AdminTableHeader("Type")
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for q in questions {
                                tr {
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        a(
                                            .href("/admin/questions/\(q.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { q.code }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { q.prompt }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { q.questionType.rawValue }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/questions/\(q.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct QuestionFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }

    let brand: any Brand
    let mode: Mode
    let form: QuestionFormValues
    let errors: QuestionFormErrors

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.pageTitle,
            activeSection: .questions,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: mode.formAction, method: mode.formMethod) {
                    TextField(
                        name: "code",
                        label: "Code",
                        value: form.code,
                        required: true,
                        helpText: "Unique handle used to reference this question from templates.",
                        error: errors.code
                    )
                    TextArea(
                        name: "prompt",
                        label: "Prompt",
                        value: form.prompt,
                        rows: 3,
                        required: true,
                        error: errors.prompt
                    )
                    SelectField(
                        QuestionType.self,
                        name: "questionType",
                        label: "Question type",
                        selected: form.typeEnum,
                        required: true,
                        error: errors.questionType
                    )
                    TextArea(
                        name: "helpText",
                        label: "Help text",
                        value: form.helpText,
                        rows: 2,
                        helpText: "Rendered as a hint below the input on the questionnaire page.",
                        error: errors.helpText
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/questions")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        p(.class("text-sm text-gray-600 mb-2")) { "Destructive actions" }
                        ConfirmDeleteForm(
                            action: "/admin/questions/\(id)",
                            label: "Delete question"
                        )
                    }
                }
            }
        }
    }
}

extension QuestionFormPage.Mode {
    var pageTitle: String {
        switch self {
        case .new: "New question"
        case .edit: "Edit question"
        }
    }

    var formAction: String {
        switch self {
        case .new: "/admin/questions"
        case .edit(let id): "/admin/questions/\(id)"
        }
    }

    var formMethod: FormMethod {
        switch self {
        case .new: .post
        case .edit: .patch
        }
    }

    var submitLabel: String {
        switch self {
        case .new: "Create question"
        case .edit: "Save changes"
        }
    }
}

struct QuestionShowPage: HTML {
    let brand: any Brand
    let question: Question

    private var questionID: String { question.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: question.code,
            activeSection: .questions,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/questions"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to questions"
                }
                LinkButton("Edit", href: "/admin/questions/\(questionID)/edit", variant: .primary)
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Code" }
                    dd(.class("font-mono text-gray-900")) { question.code }
                    dt(.class("text-gray-500")) { "Prompt" }
                    dd(.class("text-gray-900")) { question.prompt }
                    dt(.class("text-gray-500")) { "Type" }
                    dd(.class("text-gray-900")) { question.questionType.rawValue }
                    dt(.class("text-gray-500")) { "Help text" }
                    dd(.class("text-gray-900")) { question.helpText ?? "\u{2014}" }
                }
            }
        }
    }
}

struct QuestionFormValues: Sendable {
    let code: String
    let prompt: String
    let questionType: String
    let helpText: String

    init(code: String = "", prompt: String = "", questionType: String = "", helpText: String = "") {
        self.code = code
        self.prompt = prompt
        self.questionType = questionType
        self.helpText = helpText
    }

    init(question: Question) {
        self.code = question.code
        self.prompt = question.prompt
        self.questionType = question.questionType.rawValue
        self.helpText = question.helpText ?? ""
    }

    var typeEnum: QuestionType? { QuestionType(rawValue: questionType) }
}

struct QuestionFormErrors: Sendable {
    let code: String?
    let prompt: String?
    let questionType: String?
    let helpText: String?
    let summary: [String]

    init(
        code: String? = nil,
        prompt: String? = nil,
        questionType: String? = nil,
        helpText: String? = nil,
        summary: [String] = []
    ) {
        self.code = code
        self.prompt = prompt
        self.questionType = questionType
        self.helpText = helpText
        self.summary = summary
    }

    static let none = QuestionFormErrors()
}

import FluentKit
import Foundation

/// A question template used in Navigator notations.
///
/// Questions define the structure and behavior of form fields, including
/// their input types, validation rules, and display options.
public final class Question: Model, @unchecked Sendable {
    public static let schema = "questions"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "prompt")
    public var prompt: String

    @Enum(key: "question_type")
    public var questionType: QuestionType

    @Field(key: "code")
    public var code: String

    @Field(key: "help_text")
    public var helpText: String?

    @Field(key: "choices")
    public var choices: [String: String]?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        prompt: String,
        questionType: QuestionType,
        code: String,
        helpText: String? = nil,
        choices: [String: String]? = nil
    ) {
        self.prompt = prompt
        self.questionType = questionType
        self.code = code
        self.helpText = helpText
        self.choices = choices
    }
}

public enum QuestionType: String, Codable, CaseIterable, Sendable {
    /// One line of text
    case string = "string"
    /// Multi-line text stored as Content Editable
    case text = "text"
    /// Date
    case date = "date"
    /// Date and time
    case datetime = "datetime"
    /// Number
    case number = "number"
    /// Yes or No
    case yesNo = "yes_no"
    /// Radio buttons for an XOR selection
    case radio = "radio"
    /// Select dropdown for a single selection
    case select = "select"
    /// Multi-select dropdown for multiple selections
    case multiSelect = "multi_select"
    /// Sensitive data like SSNs and EINs
    case secret = "secret"
    /// Phone number that we can verify by sending an OTP message to
    case phone = "phone"
    /// Email address that we can verify by sending an OTP message to
    case email = "email"
    /// Social Security Number, with a specific format
    case ssn = "ssn"
    /// Employer Identification Number, with a specific format
    case ein = "ein"
    /// File upload
    case file = "file"
    /// Person record
    case person = "person"
    /// Address record
    case address = "address"
    /// Entity record
    case org = "org"
}

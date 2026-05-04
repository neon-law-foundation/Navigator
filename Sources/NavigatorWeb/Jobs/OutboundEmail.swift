/// A transactional email queued for delivery by ``SendEmailJob``.
///
/// Used both as the persisted payload on the queues table and as the input
/// to ``EmailSender/send(_:)``. All fields are stored as plain strings so
/// the type round-trips through `Codable` without custom adapters.
public struct OutboundEmail: Codable, Sendable, Equatable {
    /// The primary recipient's address.
    public let to: String

    /// The verified SES sender address.
    public let from: String

    /// The subject line.
    public let subject: String

    /// The plain-text message body.
    public let body: String

    /// Optional `Reply-To` address. When non-`nil`, populated into the SES
    /// `replyToAddresses` field.
    public let replyTo: String?

    public init(to: String, from: String, subject: String, body: String, replyTo: String? = nil) {
        self.to = to
        self.from = from
        self.subject = subject
        self.body = body
        self.replyTo = replyTo
    }
}

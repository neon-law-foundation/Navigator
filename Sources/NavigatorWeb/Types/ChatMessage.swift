/// A single message in a `ChatInterface` conversation.
///
/// User messages have `role == .user` and no citations; assistant replies
/// have `role == .assistant` and may include a list of `Citation`s drawn
/// from the files passed as context.
public struct ChatMessage: Sendable, Equatable, Codable {
    /// Who authored the message.
    public enum Role: String, Sendable, Equatable, Codable {
        case user
        case assistant
    }

    /// Stable identifier for the message; used as a DOM hook for citation
    /// disclosure panels.
    public let id: String

    /// Who authored the message.
    public let role: Role

    /// Plain-text body of the message.
    public let content: String

    /// Supporting passages the assistant cited, if any. Empty for user
    /// messages.
    public let citations: [Citation]

    public init(
        id: String,
        role: Role,
        content: String,
        citations: [Citation] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.citations = citations
    }
}

/// A citation attached to an assistant `ChatMessage`.
///
/// Surfaces the originating document and the specific passage the assistant
/// drew from so visitors can click through to the viewer and verify the
/// quote. `documentId` points at a `WorkshopFile.id`; `documentName` is
/// denormalised onto the citation so list views render without an extra
/// lookup against the file catalogue.
public struct Citation: Sendable, Equatable, Codable {
    /// Identifier of the cited `WorkshopFile`.
    public let documentId: String

    /// Denormalised display name of the cited document.
    public let documentName: String

    /// The quoted passage from the document.
    public let passage: String

    public init(documentId: String, documentName: String, passage: String) {
        self.documentId = documentId
        self.documentName = documentName
        self.passage = passage
    }
}

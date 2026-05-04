import FluentKit
import Foundation

/// Computes the ``EmailMessage/threadId`` for an incoming email by walking
/// the RFC 5322 `In-Reply-To` and `References` headers.
///
/// ## Algorithm
///
/// The resolver follows a three-step hybrid strategy:
///
/// 1. **Direct reply** — if `In-Reply-To` names a message that already exists
///    in `email_messages`, inherit that parent's ``EmailMessage/threadId``.
/// 2. **Ancestor walk** — otherwise, iterate the `References` header
///    head-to-tail (oldest first) looking for any ancestor that already
///    exists. The first match wins and its thread id is adopted.
/// 3. **New root** — if no prior message in the chain is known, the incoming
///    message becomes a new thread root. Its own ``EmailMessage/messageId``
///    becomes its ``EmailMessage/threadId``.
///
/// ### Orphan handling (v1)
///
/// If a reply arrives before its parent (for example, because the parent
/// was lost in a retry), the orphan is treated as a new root. No later
/// re-parenting is performed — a future revision may add JWZ-style
/// merge-on-parent-arrival logic if thread fragmentation becomes a real
/// pain point.
///
/// ## Usage
///
/// ```swift
/// let resolver = EmailThreadResolver(database: db)
/// let threadId = try await resolver.resolveThreadId(
///     messageId: "<20260410.abc@example.com>",
///     inReplyTo: "<20260409.xyz@example.com>",
///     references: []
/// )
/// ```
public struct EmailThreadResolver: Sendable {

    private let repository: EmailMessageRepository

    /// Creates a new `EmailThreadResolver`.
    ///
    /// - Parameter database: The Fluent database connection used for ancestor lookups.
    public init(database: Database) {
        self.repository = EmailMessageRepository(database: database)
    }

    /// Resolves the thread id for an incoming email.
    ///
    /// - Parameters:
    ///   - messageId: The `Message-ID` of the incoming email, including angle brackets.
    ///   - inReplyTo: The `In-Reply-To` header value, if any.
    ///   - references: The parsed `References` header as an ordered list of ancestor
    ///     `Message-ID` values. Oldest first; the immediate parent is last.
    /// - Returns: The thread id the incoming message should adopt.
    public func resolveThreadId(
        messageId: String,
        inReplyTo: String?,
        references: [String]
    ) async throws -> String {
        if let parentId = inReplyTo,
            let parent = try await repository.findByMessageId(parentId)
        {
            return parent.threadId
        }

        for ancestorId in references {
            if let ancestor = try await repository.findByMessageId(ancestorId) {
                return ancestor.threadId
            }
        }

        return messageId
    }
}

import FluentKit
import Foundation

/// Represents a physical mailroom office that manages addressed mailboxes.
///
/// An `Address` record is a managed mailbox when its `mailroom_id` foreign key
/// points to a `Mailroom`. The mailroom defines the name and mailbox number range
/// for a physical office location.
public final class Mailroom: Model, @unchecked Sendable {
    public static let schema = "mailrooms"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "mailbox_start")
    public var mailboxStart: Int

    @Field(key: "mailbox_end")
    public var mailboxEnd: Int

    @OptionalField(key: "capacity")
    public var capacity: Int?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}

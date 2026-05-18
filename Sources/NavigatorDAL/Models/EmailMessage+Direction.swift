import Foundation

/// Whether an ``EmailMessage`` row is a record of mail this firm received
/// or mail this firm sent.
///
/// Stored implicitly through the existing `from_address` / `to_address`
/// columns rather than a discriminator column — see ``EmailMessage/direction``.
public enum EmailMessageDirection: String, Sendable {
    case inbound
    case outbound
}

extension EmailMessage {

    /// The canonical set of mailboxes this deployment sends mail *from*.
    /// Inbound mail flips the from/to columns relative to outbound, so a
    /// row whose `from_address` matches one of these is something we
    /// generated, not something we received.
    ///
    /// The set is intentionally tiny: each deployment runs a single
    /// `support@<brand-domain>` mailbox. Adding a new brand means adding
    /// its support address here.
    public static let supportFromAddresses: Set<String> = [
        "support@neonlaw.org"
    ]

    /// Direction inferred from the addresses on the row.
    ///
    /// `from_address` is compared case-insensitively against
    /// ``supportFromAddresses``. A row whose sender is one of our own
    /// support mailboxes is outbound; everything else is inbound. This
    /// approach was chosen over adding a `direction` discriminator column
    /// so the schema stays single-purpose and the inbound ingestion path
    /// keeps writing rows exactly the way it does today.
    public var direction: EmailMessageDirection {
        Self.supportFromAddresses.contains(fromAddress.lowercased())
            ? .outbound : .inbound
    }

    /// Sentinel value stored in the four SES verdict columns for outbound
    /// rows.
    ///
    /// The verdict columns are `NOT NULL` in the schema today because SES
    /// always supplies a verdict for inbound mail; outbound rows have no
    /// SES verdict to record, so they store this sentinel instead of
    /// inventing a plausible-but-wrong value. The columns stay informative
    /// for the inbound case and an outbound reader can spot the sentinel
    /// at a glance.
    public static let outboundVerdictSentinel = "NOT_APPLICABLE"
}

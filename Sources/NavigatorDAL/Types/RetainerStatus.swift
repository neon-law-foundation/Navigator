import Foundation

/// Lifecycle states for a ``Retainer``.
///
/// Transitions:
/// - `pendingSignature` → `active` (when the linked notation reaches terminal state `"END"`)
/// - `active` → `suspended` or `closed` (staff action)
public enum RetainerStatus: String, Codable, CaseIterable, Sendable {
    /// Awaiting the client's signature on the retainer agreement notation.
    case pendingSignature = "pending_signature"
    /// The retainer is signed and the client has active access to linked projects.
    case active = "active"
    /// Access is temporarily paused by staff.
    case suspended = "suspended"
    /// The matter is closed; access is permanently ended.
    case closed = "closed"
}

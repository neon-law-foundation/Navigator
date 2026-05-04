import Foundation

/// Lifecycle states for a ``Project``.
///
/// Transitions:
/// - `active` → `closed` (matter resolved)
/// - `active` → `archived` (matter placed in long-term storage)
public enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    /// The project is open and work is ongoing.
    case active
    /// The matter is resolved; no further work is expected.
    case closed
    /// The project is closed and moved to long-term storage.
    case archived
}

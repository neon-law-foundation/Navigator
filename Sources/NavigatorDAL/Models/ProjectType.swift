import Foundation

/// Classification of a ``Project`` by matter type.
public enum ProjectType: String, Codable, CaseIterable, Sendable {
    /// An adversarial dispute in court or arbitration.
    case litigation
    /// A deal, financing, or other transactional matter.
    case transaction
    /// A counseling or opinion matter with no opposing party.
    case advisory
}

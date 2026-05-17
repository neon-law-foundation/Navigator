/// A single step in a `WorkshopTour`.
///
/// `WorkshopTour` currently renders only a static list of steps; the
/// fields `placement` and `disableBeacon` are preserved on the model so
/// the full guided-tour UX can light up later without a breaking API
/// change.
public struct TourStep: Sendable, Equatable, Codable {
    /// Tooltip placement relative to `target`.
    public enum Placement: String, Sendable, Equatable, Codable {
        case top
        case bottom
        case left
        case right
        case center
        case auto
    }

    /// CSS selector for the spotlight target.
    public let target: String

    /// Body content of the step tooltip.
    public let content: String

    /// Optional heading rendered above the content.
    public let title: String?

    /// Optional spotlight placement relative to the target.
    public let placement: Placement?

    /// If true, skip the pulsing beacon and open the tooltip immediately.
    public let disableBeacon: Bool?

    public init(
        target: String,
        content: String,
        title: String? = nil,
        placement: Placement? = nil,
        disableBeacon: Bool? = nil
    ) {
        self.target = target
        self.content = content
        self.title = title
        self.placement = placement
        self.disableBeacon = disableBeacon
    }
}

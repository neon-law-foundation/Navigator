/// A single step in a `WorkshopTour`.
///
/// The shape mirrors the subset of React Joyride's `Step` interface that
/// the archived NLF/WebComponents library exposed, so callers migrating
/// tours from the TypeScript side do not need to re-key their data.
///
/// Introduced in Milestone 2 of the pure-Swift web stack migration
/// (sagebrush-services/AWS#112) as part of the `WorkshopTour` stub. The
/// Swift-side tour currently renders only a static list of steps; the
/// fields `placement` and `disableBeacon` are preserved on the model so
/// the full guided-tour UX (deferred from M2) can light up without a
/// breaking API change.
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

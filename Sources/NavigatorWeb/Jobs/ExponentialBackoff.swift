/// A retry-delay schedule that grows geometrically with each attempt.
///
/// Used by ``NavigatorJob`` conformers to compute the value returned from
/// `nextRetryIn(attempt:)`. Pure, deterministic computation — no jitter —
/// so call sites can be exercised in tests without a clock.
///
/// `delaySeconds(forAttempt:)` returns
/// `baseSeconds * multiplier^(attempt - 1)`, clamped to `maxDelaySeconds`
/// when set. Attempt numbers are 1-indexed: attempt `1` is the delay
/// before the first retry that follows the initial failed dequeue.
public struct ExponentialBackoff: Sendable, Equatable {
    /// The delay before the first retry, in seconds.
    public let baseSeconds: Int

    /// The factor by which each successive delay is multiplied.
    public let multiplier: Int

    /// The maximum delay, in seconds, beyond which the schedule clamps.
    public let maxDelaySeconds: Int?

    /// Creates a new schedule. Defaults match the conventions documented in
    /// the Vapor Queues + ``SendEmailJob`` rollout: 5-second base, doubling
    /// each attempt, no upper bound.
    public init(baseSeconds: Int = 5, multiplier: Int = 2, maxDelaySeconds: Int? = nil) {
        self.baseSeconds = baseSeconds
        self.multiplier = multiplier
        self.maxDelaySeconds = maxDelaySeconds
    }

    /// The default schedule used by ``NavigatorJob`` when conformers do not
    /// override ``NavigatorJob/backoffSchedule``.
    public static let `default` = ExponentialBackoff()

    /// Returns the delay, in seconds, before retry attempt `attempt`.
    ///
    /// `attempt` is 1-indexed. Non-positive values return `0`, mirroring
    /// the Vapor Queues default of "no delay".
    public func delaySeconds(forAttempt attempt: Int) -> Int {
        guard attempt >= 1 else { return 0 }
        var delay = baseSeconds
        var step = 1
        while step < attempt {
            let next = delay.multipliedReportingOverflow(by: multiplier)
            if next.overflow {
                return maxDelaySeconds ?? Int.max
            }
            delay = next.partialValue
            if let cap = maxDelaySeconds, delay >= cap {
                return cap
            }
            step += 1
        }
        return delay
    }
}

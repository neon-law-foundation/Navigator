import Queues

/// A Vapor Queues job that retries with exponential backoff.
///
/// Conformers gain a default `nextRetryIn(attempt:)` driven by
/// ``ExponentialBackoff``. Override ``backoffSchedule`` to customise the
/// base delay, multiplier, or cap; override `nextRetryIn` directly only if
/// the job needs non-exponential behaviour.
///
/// Total attempt count is governed by `maxRetryCount` on the dispatched
/// `JobData`, which call sites set when enqueuing — keep that responsibility
/// at the enqueue boundary so jobs themselves stay declarative.
public protocol NavigatorJob: AsyncJob {
    /// The retry-delay schedule applied to this job.
    static var backoffSchedule: ExponentialBackoff { get }
}

extension NavigatorJob {
    public static var backoffSchedule: ExponentialBackoff {
        .default
    }

    public func nextRetryIn(attempt: Int) -> Int {
        Self.backoffSchedule.delaySeconds(forAttempt: attempt)
    }
}

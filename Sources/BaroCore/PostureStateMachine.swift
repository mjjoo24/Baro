import Foundation

public final class PostureStateMachine {
    public private(set) var state: PostureState = .good
    public var thresholds: PostureThresholds

    private var badStreakStart: Date?
    private var goodStreakStart: Date?
    private var lastSampleTime: Date?

    public init(thresholds: PostureThresholds = .default) {
        self.thresholds = thresholds
    }

    @discardableResult
    public func update(score: Double, at time: Date) -> PostureState {
        defer { lastSampleTime = time }

        let isBad = score >= thresholds.badScoreThreshold

        if isBad {
            goodStreakStart = nil
            let start = badStreakStart ?? time
            badStreakStart = start
            let duration = time.timeIntervalSince(start)

            if duration >= thresholds.criticalDuration {
                state = .critical
            } else if duration >= thresholds.warningDuration {
                state = .warning
            }
        } else {
            badStreakStart = nil
            let start = goodStreakStart ?? time
            goodStreakStart = start
            let duration = time.timeIntervalSince(start)

            if duration >= thresholds.recoveryDebounce {
                state = .good
            }
        }

        return state
    }

    public func recordFaceNotDetected(at time: Date) {
        if let last = lastSampleTime, time.timeIntervalSince(last) >= thresholds.faceLossResetAfter {
            reset()
        }
        lastSampleTime = time
    }

    public func reset() {
        state = .good
        badStreakStart = nil
        goodStreakStart = nil
    }
}

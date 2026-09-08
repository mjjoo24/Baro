import Foundation

public struct PostureScoreBreakdown: Equatable, Sendable {
    public let forward: Double
    public let downward: Double
    public let tilt: Double
    public let turn: Double
    public let total: Double

    public init(forward: Double, downward: Double, tilt: Double, turn: Double = 0, total: Double) {
        self.forward = forward
        self.downward = downward
        self.tilt = tilt
        self.turn = turn
        self.total = total
    }

    public var rawTotal: Double {
        forward + downward + tilt + turn
    }

    public var postureQualityScore: Double {
        min(100, forward + downward + tilt)
    }

    public static let zero = PostureScoreBreakdown(forward: 0, downward: 0, tilt: 0, turn: 0, total: 0)
}

public struct PostureScorer: Sendable {
    public var weights: PostureScoringWeights

    public init(weights: PostureScoringWeights = .default) {
        self.weights = weights
    }

    public func score(baseline: FaceLandmarkSnapshot, current: FaceLandmarkSnapshot) -> Double {
        scoreBreakdown(baseline: baseline, current: current).total
    }

    public func scoreBreakdown(baseline: FaceLandmarkSnapshot, current: FaceLandmarkSnapshot) -> PostureScoreBreakdown {
        let forward = min(1, max(0, forwardShiftRatio(baseline: baseline, current: current) / weights.forwardFullScaleRatio)) * 100
        let downward = min(1, max(0, downwardShift(baseline: baseline, current: current) / weights.downwardFullScaleRatio)) * 100
        let tilt = min(1, tiltDeltaDegrees(baseline: baseline, current: current) / weights.tiltFullScaleDegrees) * 100
        let turn = min(1, turnDelta(baseline: baseline, current: current) / weights.turnFullScaleRatio) * 100

        let total = min(100, max(0, forward + downward + tilt + turn))

        return PostureScoreBreakdown(forward: forward, downward: downward, tilt: tilt, turn: turn, total: total)
    }

    private func forwardShiftRatio(baseline: FaceLandmarkSnapshot, current: FaceLandmarkSnapshot) -> Double {
        guard baseline.faceBoundingBoxWidth > 0 else { return 0 }
        return (current.faceBoundingBoxWidth - baseline.faceBoundingBoxWidth) / baseline.faceBoundingBoxWidth
    }

    private func downwardShift(baseline: FaceLandmarkSnapshot, current: FaceLandmarkSnapshot) -> Double {
        current.averageEyeY - baseline.averageEyeY
    }

    private func tiltDeltaDegrees(baseline: FaceLandmarkSnapshot, current: FaceLandmarkSnapshot) -> Double {
        abs(current.tiltAngleDegrees - baseline.tiltAngleDegrees)
    }

    private func turnDelta(baseline: FaceLandmarkSnapshot, current: FaceLandmarkSnapshot) -> Double {
        abs(current.turnOffsetRatio - baseline.turnOffsetRatio)
    }
}

import Foundation

public struct PostureMatch: Equatable, Sendable {
    public let postureID: UUID
    public let postureName: String
    public let breakdown: PostureScoreBreakdown

    public init(postureID: UUID, postureName: String, breakdown: PostureScoreBreakdown) {
        self.postureID = postureID
        self.postureName = postureName
        self.breakdown = breakdown
    }
}

public enum PostureRegistrationWarning: Equatable, Sendable {
    case duplicate(existingName: String)
    case worseThanRegistered(existingName: String, score: Double)
}

public struct PostureMatcher: Sendable {
    public var scorer: PostureScorer
    public var stabilityChecker: CalibrationStabilityChecker
    public var unmeasurableTurnScore: Double
    public var duplicateMovementRatio: Double
    public var worseRegistrationScore: Double

    public init(
        scorer: PostureScorer = PostureScorer(),
        stabilityChecker: CalibrationStabilityChecker = CalibrationStabilityChecker(),
        unmeasurableTurnScore: Double = 100,
        duplicateMovementRatio: Double = 1,
        worseRegistrationScore: Double = 35
    ) {
        self.scorer = scorer
        self.stabilityChecker = stabilityChecker
        self.unmeasurableTurnScore = unmeasurableTurnScore
        self.duplicateMovementRatio = duplicateMovementRatio
        self.worseRegistrationScore = worseRegistrationScore
    }

    public func bestMatch(postures: [CalibratedPosture], current: FaceLandmarkSnapshot) -> PostureMatch? {
        var best: PostureMatch?
        for posture in postures {
            let breakdown = scorer.scoreBreakdown(baseline: posture.snapshot, current: current)
            if best == nil || breakdown.rawTotal < best!.breakdown.rawTotal {
                best = PostureMatch(postureID: posture.id, postureName: posture.name, breakdown: breakdown)
            }
        }
        return best
    }

    public func isUnmeasurable(_ match: PostureMatch) -> Bool {
        match.breakdown.turn >= unmeasurableTurnScore
    }

    public func registrationWarning(
        candidate: FaceLandmarkSnapshot,
        existing: [CalibratedPosture]
    ) -> PostureRegistrationWarning? {
        guard !existing.isEmpty else { return nil }

        var closest: (posture: CalibratedPosture, ratio: Double)?
        for posture in existing {
            let ratio = stabilityChecker.movementRatio(reference: posture.snapshot, sample: candidate)
            if closest == nil || ratio < closest!.ratio {
                closest = (posture, ratio)
            }
        }
        if let closest, closest.ratio <= duplicateMovementRatio {
            return .duplicate(existingName: closest.posture.name)
        }

        var mildest: PostureMatch?
        for posture in existing {
            let breakdown = scorer.scoreBreakdown(baseline: posture.snapshot, current: candidate)
            let match = PostureMatch(postureID: posture.id, postureName: posture.name, breakdown: breakdown)
            if mildest == nil || breakdown.postureQualityScore < mildest!.breakdown.postureQualityScore {
                mildest = match
            }
        }

        guard let mildest, mildest.breakdown.postureQualityScore >= worseRegistrationScore else {
            return nil
        }
        return .worseThanRegistered(existingName: mildest.postureName, score: mildest.breakdown.postureQualityScore)
    }
}

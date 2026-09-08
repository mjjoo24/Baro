import Foundation

public enum CalibrationAbortReason: Equatable, Sendable {
    case moved
    case faceLost
}

public struct CalibrationStabilityChecker: Sendable {
    public var widthRatioLimit: Double
    public var verticalShiftLimit: Double
    public var horizontalShiftLimit: Double
    public var tiltDeltaLimitDegrees: Double
    public var turnDeltaLimitRatio: Double
    public var faceLossFrameLimit: Int

    public init(
        widthRatioLimit: Double = 0.12,
        verticalShiftLimit: Double = 0.05,
        horizontalShiftLimit: Double = 0.06,
        tiltDeltaLimitDegrees: Double = 8,
        turnDeltaLimitRatio: Double = 0.03,
        faceLossFrameLimit: Int = 3
    ) {
        self.widthRatioLimit = widthRatioLimit
        self.verticalShiftLimit = verticalShiftLimit
        self.horizontalShiftLimit = horizontalShiftLimit
        self.tiltDeltaLimitDegrees = tiltDeltaLimitDegrees
        self.turnDeltaLimitRatio = turnDeltaLimitRatio
        self.faceLossFrameLimit = faceLossFrameLimit
    }

    public func movementRatio(reference: FaceLandmarkSnapshot, sample: FaceLandmarkSnapshot) -> Double {
        let widthRatio: Double
        if reference.faceBoundingBoxWidth > 0 {
            let delta = abs(sample.faceBoundingBoxWidth - reference.faceBoundingBoxWidth)
            widthRatio = delta / reference.faceBoundingBoxWidth / widthRatioLimit
        } else {
            widthRatio = 0
        }

        let verticalRatio = abs(sample.averageEyeY - reference.averageEyeY) / verticalShiftLimit

        let horizontalRatio = abs(sample.eyeCenterX - reference.eyeCenterX) / horizontalShiftLimit
        let tiltRatio = abs(sample.tiltAngleDegrees - reference.tiltAngleDegrees) / tiltDeltaLimitDegrees
        let turnRatio = abs(sample.turnOffsetRatio - reference.turnOffsetRatio) / turnDeltaLimitRatio

        return max(max(widthRatio, verticalRatio), max(max(horizontalRatio, tiltRatio), turnRatio))
    }

    public func hasMoved(reference: FaceLandmarkSnapshot, sample: FaceLandmarkSnapshot) -> Bool {
        movementRatio(reference: reference, sample: sample) > 1
    }

    public func hasLostFace(consecutiveMissingFrames: Int) -> Bool {
        consecutiveMissingFrames >= faceLossFrameLimit
    }
}

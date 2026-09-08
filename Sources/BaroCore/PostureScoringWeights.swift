import Foundation

public struct PostureScoringWeights: Equatable, Sendable {
    public var forwardFullScaleRatio: Double
    public var downwardFullScaleRatio: Double
    public var tiltFullScaleDegrees: Double
    public var turnFullScaleRatio: Double

    public init(
        forwardFullScaleRatio: Double = 0.3,
        downwardFullScaleRatio: Double = 0.15,
        tiltFullScaleDegrees: Double = 30,
        turnFullScaleRatio: Double = 0.12
    ) {
        self.forwardFullScaleRatio = forwardFullScaleRatio
        self.downwardFullScaleRatio = downwardFullScaleRatio
        self.tiltFullScaleDegrees = tiltFullScaleDegrees
        self.turnFullScaleRatio = turnFullScaleRatio
    }

    public static let `default` = PostureScoringWeights()
}

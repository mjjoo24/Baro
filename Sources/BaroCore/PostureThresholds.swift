import Foundation

public struct PostureThresholds: Equatable, Sendable {
    public var badScoreThreshold: Double

    public var warningDuration: TimeInterval

    public var criticalDuration: TimeInterval

    public var recoveryDebounce: TimeInterval

    public var faceLossResetAfter: TimeInterval

    public init(
        badScoreThreshold: Double = 40,
        warningDuration: TimeInterval = 10,
        criticalDuration: TimeInterval = 30,
        recoveryDebounce: TimeInterval = 2,
        faceLossResetAfter: TimeInterval = 15
    ) {
        self.badScoreThreshold = badScoreThreshold
        self.warningDuration = warningDuration
        self.criticalDuration = criticalDuration
        self.recoveryDebounce = recoveryDebounce
        self.faceLossResetAfter = faceLossResetAfter
    }

    public static let `default` = PostureThresholds()
}

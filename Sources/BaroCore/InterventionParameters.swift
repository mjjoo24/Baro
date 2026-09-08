import Foundation

public struct InterventionParameters: Equatable, Sendable {
    public var badScoreThreshold: Double
    public var warningDuration: TimeInterval
    public var criticalDelayAfterWarning: TimeInterval
    public var intensity: InterventionIntensity

    public init(
        badScoreThreshold: Double,
        warningDuration: TimeInterval,
        criticalDelayAfterWarning: TimeInterval,
        intensity: InterventionIntensity
    ) {
        self.badScoreThreshold = badScoreThreshold
        self.warningDuration = warningDuration
        self.criticalDelayAfterWarning = criticalDelayAfterWarning
        self.intensity = intensity
    }

    public var thresholds: PostureThresholds {
        PostureThresholds(
            badScoreThreshold: badScoreThreshold,
            warningDuration: warningDuration,
            criticalDuration: warningDuration + criticalDelayAfterWarning
        )
    }

    public func applying(_ overrides: PresetOverrides?) -> InterventionParameters {
        guard let overrides else { return self }
        var resolved = self
        if let value = overrides.badScoreThreshold { resolved.badScoreThreshold = value }
        if let value = overrides.warningDuration { resolved.warningDuration = value }
        if let value = overrides.criticalDelayAfterWarning { resolved.criticalDelayAfterWarning = value }
        if let value = overrides.intensity { resolved.intensity = value }
        return resolved
    }
}

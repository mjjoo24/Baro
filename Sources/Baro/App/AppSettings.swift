import Foundation
import BaroCore

public struct AppSettings: Codable, Equatable {
    public var badScoreThreshold: Double
    public var warningDuration: TimeInterval
    public var criticalDelayAfterWarning: TimeInterval
    public var intensity: InterventionIntensity
    public var cameraEnabled: Bool
    public var launchAtLogin: Bool

    public var parameters: InterventionParameters {
        InterventionParameters(
            badScoreThreshold: badScoreThreshold,
            warningDuration: warningDuration,
            criticalDelayAfterWarning: criticalDelayAfterWarning,
            intensity: intensity
        )
    }

    public var thresholds: PostureThresholds {
        parameters.thresholds
    }

    public func applying(_ overrides: PresetOverrides?) -> AppSettings {
        let resolved = parameters.applying(overrides)
        var updated = self
        updated.badScoreThreshold = resolved.badScoreThreshold
        updated.warningDuration = resolved.warningDuration
        updated.criticalDelayAfterWarning = resolved.criticalDelayAfterWarning
        updated.intensity = resolved.intensity
        return updated
    }

    public static let `default` = AppSettings(
        badScoreThreshold: 45,
        warningDuration: 3,
        criticalDelayAfterWarning: 5,
        intensity: .dim,
        cameraEnabled: true,
        launchAtLogin: false
    )

    private static let defaultsKey = "com.baro.settings"

    public static func load(userDefaults: UserDefaults = .standard) -> AppSettings {
        guard let data = userDefaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        userDefaults.set(data, forKey: Self.defaultsKey)
    }
}

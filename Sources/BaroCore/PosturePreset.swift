import Foundation

public struct CalibratedPosture: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var snapshot: FaceLandmarkSnapshot
    public var capturedAt: Date?

    public init(id: UUID = UUID(), name: String, snapshot: FaceLandmarkSnapshot, capturedAt: Date? = Date()) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
        self.capturedAt = capturedAt
    }
}

public struct ScreenSignature: Equatable, Sendable, Codable {
    public var displaySizes: [String]

    public init(displaySizes: [String]) {
        self.displaySizes = displaySizes.sorted()
    }

    public var displayCount: Int { displaySizes.count }

    public var summary: String {
        displayCount == 1 ? "화면 1대" : "화면 \(displayCount)대"
    }
}

public struct PresetOverrides: Equatable, Sendable, Codable {
    public var badScoreThreshold: Double?
    public var warningDuration: TimeInterval?
    public var criticalDelayAfterWarning: TimeInterval?
    public var intensity: InterventionIntensity?

    public init(
        badScoreThreshold: Double? = nil,
        warningDuration: TimeInterval? = nil,
        criticalDelayAfterWarning: TimeInterval? = nil,
        intensity: InterventionIntensity? = nil
    ) {
        self.badScoreThreshold = badScoreThreshold
        self.warningDuration = warningDuration
        self.criticalDelayAfterWarning = criticalDelayAfterWarning
        self.intensity = intensity
    }

    public var isEmpty: Bool {
        badScoreThreshold == nil
            && warningDuration == nil
            && criticalDelayAfterWarning == nil
            && intensity == nil
    }
}

public struct PosturePreset: Identifiable, Equatable, Sendable, Codable {
    public static let maxPostures = 5

    public var id: UUID
    public var name: String
    public var postures: [CalibratedPosture]
    public var screenSignature: ScreenSignature?
    public var overrides: PresetOverrides?

    public init(
        id: UUID = UUID(),
        name: String,
        postures: [CalibratedPosture] = [],
        screenSignature: ScreenSignature? = nil,
        overrides: PresetOverrides? = nil
    ) {
        self.id = id
        self.name = name
        self.postures = postures
        self.screenSignature = screenSignature
        self.overrides = overrides
    }

    public var isCalibrated: Bool { !postures.isEmpty }

    public var canAddPosture: Bool { postures.count < Self.maxPostures }

    public func posture(with id: UUID) -> CalibratedPosture? {
        postures.first { $0.id == id }
    }

    public func nextPostureName() -> String {
        let used = Set(postures.map(\.name))
        for index in 1...Self.maxPostures where !used.contains("자세 \(index)") {
            return "자세 \(index)"
        }
        return "자세 \(postures.count + 1)"
    }
}

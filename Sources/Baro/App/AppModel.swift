import Combine
import Foundation
import BaroCore

public enum CalibrationPresentation: Equatable {
    case menuBar
    case settings
}

public enum CalibrationTarget: Equatable {
    case newPosture
    case replace(postureID: UUID)
}

public struct PendingPostureRegistration: Equatable {
    public var snapshot: FaceLandmarkSnapshot
    public var warning: PostureRegistrationWarning
    public var target: CalibrationTarget
}

@MainActor
public final class AppModel: ObservableObject {
    public let monitor: PostureMonitor
    public let intervention = InterventionController()
    public let screens = ScreenConfigurationMonitor()

    @Published public var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            applySettings()
        }
    }

    @Published public var library: PresetLibrary {
        didSet {
            guard library != oldValue else { return }
            presetStore.replace(with: library)
            if library.activePostures != oldValue.activePostures {
                monitor.updatePostures(library.activePostures)
            }
            applySettings()
        }
    }

    @Published public private(set) var todayBadPostureSeconds: TimeInterval = 0
    @Published public private(set) var todayBadSecondsByPosture: [UUID: TimeInterval] = [:]
    @Published public private(set) var pendingRegistration: PendingPostureRegistration? {
        didSet { updateCalibrationSuppression() }
    }
    @Published public private(set) var autoSwitchedPresetName: String?

    public private(set) var calibrationTarget: CalibrationTarget = .newPosture
    @Published public private(set) var calibrationPresentation: CalibrationPresentation = .menuBar

    public var isCalibrationFlowActive: Bool {
        monitor.isCalibrationScreenRequested || monitor.isCalibrating || pendingRegistration != nil
    }

    private let presetStore: PresetStore
    private let matcher = PostureMatcher()
    private var nonGoodStreakStart: Date?
    private var nonGoodStreakPostureID: UUID?
    private var statsDay: Date = Calendar.current.startOfDay(for: Date())
    private var cancellables: Set<AnyCancellable> = []

    public init() {
        let presetStore = PresetStore(persistence: FilePresetPersistence())
        let loadedSettings = AppSettings.load()
        self.presetStore = presetStore
        self.settings = loadedSettings
        self.library = presetStore.library
        let resolved = loadedSettings.applying(presetStore.library.activePreset.overrides)
        self.monitor = PostureMonitor(
            postures: presetStore.library.activePostures,
            thresholds: resolved.thresholds
        )
        self.intervention.intensity = resolved.intensity

        if loadedSettings.launchAtLogin != LaunchAtLoginManager.isEnabled {
            self.settings.launchAtLogin = LaunchAtLoginManager.isEnabled
            self.settings.save()
        }

        monitor.onStateChange = { [weak self] state in
            self?.handleStateChange(state)
        }

        monitor.onCalibrationCaptured = { [weak self] snapshot in
            self?.handleCalibrationCaptured(snapshot)
        }

        screens.onChange = { [weak self] signature in
            self?.applyScreenSignature(signature)
        }

        monitor.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        intervention.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        monitor.$isCameraBusyElsewhere
            .sink { [weak self] busy in self?.intervention.setCameraConflict(busy) }
            .store(in: &cancellables)

        monitor.$scoreBreakdown
            .sink { [weak self] breakdown in self?.forwardLiveScore(breakdown) }
            .store(in: &cancellables)

        monitor.$isCalibrationScreenRequested
            .combineLatest(monitor.$isCalibrating)
            .map { $0 || $1 }
            .removeDuplicates()
            .sink { [weak self] active in self?.updateCalibrationSuppression(active) }
            .store(in: &cancellables)

        if loadedSettings.cameraEnabled, CaptureManager.currentAuthorizationState() != .notDetermined {
            monitor.start()
        }
    }

    public var resolvedSettings: AppSettings {
        settings.applying(library.activePreset.overrides)
    }

    public func primeCamera() {
        monitor.start()
    }

    public func requestNewPosture(from presentation: CalibrationPresentation = .menuBar) {
        guard library.activePreset.canAddPosture else { return }
        calibrationTarget = .newPosture
        calibrationPresentation = presentation
        pendingRegistration = nil
        monitor.requestCalibrationScreen()
    }

    public func requestRecalibration(postureID: UUID, from presentation: CalibrationPresentation = .menuBar) {
        calibrationTarget = .replace(postureID: postureID)
        calibrationPresentation = presentation
        pendingRegistration = nil
        monitor.requestCalibrationScreen()
    }

    public func requestRecalibration() {
        if let first = library.activePreset.postures.first {
            requestRecalibration(postureID: first.id)
        } else {
            requestNewPosture()
        }
    }

    public func beginCalibration() {
        monitor.beginCalibration()
    }

    public func cancelCalibrationScreen() {
        pendingRegistration = nil
        monitor.cancelCalibrationScreenRequest()
    }

    public func confirmPendingRegistration() {
        guard let pending = pendingRegistration else { return }
        pendingRegistration = nil
        commitPosture(pending.snapshot, target: pending.target)
    }

    public func discardPendingRegistration() {
        pendingRegistration = nil
        monitor.requestCalibrationScreen()
    }

    public func snooze(minutes: Int) {
        intervention.snooze(for: TimeInterval(minutes * 60))
    }

    public func cancelSnooze() {
        intervention.cancelSnooze()
    }

    public func selectPreset(_ presetID: UUID) {
        guard library.activePresetID != presetID else { return }
        autoSwitchedPresetName = nil
        library.activePresetID = presetID
    }

    public func addPreset() {
        library.addPreset()
    }

    public func duplicateActivePreset() {
        library.duplicatePreset(library.activePresetID)
    }

    public func removePreset(_ presetID: UUID) {
        library.removePreset(presetID)
    }

    public func renamePreset(_ presetID: UUID, to name: String) {
        library.update(presetID: presetID) { $0.name = name }
    }

    public func renamePosture(_ postureID: UUID, to name: String) {
        library.updateActivePreset { preset in
            guard let index = preset.postures.firstIndex(where: { $0.id == postureID }) else { return }
            preset.postures[index].name = name
        }
    }

    public func removePosture(_ postureID: UUID) {
        library.removePosture(postureID, from: library.activePresetID)
    }

    public func bindActivePresetToCurrentScreens() {
        let signature = ScreenConfigurationMonitor.currentSignature()
        let activeID = library.activePresetID
        var updated = library
        for index in updated.presets.indices where updated.presets[index].screenSignature == signature {
            updated.presets[index].screenSignature = nil
        }
        updated.update(presetID: activeID) { $0.screenSignature = signature }
        library = updated
    }

    public func unbindActivePresetFromScreens() {
        library.updateActivePreset { $0.screenSignature = nil }
    }

    public func updateActiveOverrides(_ overrides: PresetOverrides?) {
        library.updateActivePreset { preset in
            preset.overrides = (overrides?.isEmpty ?? true) ? nil : overrides
        }
    }

    public func badSeconds(for postureID: UUID) -> TimeInterval {
        todayBadSecondsByPosture[postureID] ?? 0
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        LaunchAtLoginManager.setEnabled(enabled)
    }

    public func toggleCamera(_ enabled: Bool) {
        settings.cameraEnabled = enabled
        if enabled {
            monitor.start()
        } else {
            monitor.stop()
        }
    }

    private func handleCalibrationCaptured(_ snapshot: FaceLandmarkSnapshot) {
        let target = calibrationTarget
        let existing = library.activePreset.postures.filter { posture in
            if case .replace(let id) = target { return posture.id != id }
            return true
        }

        if let warning = matcher.registrationWarning(candidate: snapshot, existing: existing) {
            pendingRegistration = PendingPostureRegistration(snapshot: snapshot, warning: warning, target: target)
            return
        }
        commitPosture(snapshot, target: target)
    }

    private func commitPosture(_ snapshot: FaceLandmarkSnapshot, target: CalibrationTarget) {
        library.updateActivePreset { preset in
            switch target {
            case .newPosture:
                guard preset.canAddPosture else { return }
                preset.postures.append(CalibratedPosture(name: preset.nextPostureName(), snapshot: snapshot))
            case .replace(let postureID):
                if let index = preset.postures.firstIndex(where: { $0.id == postureID }) {
                    preset.postures[index].snapshot = snapshot
                    preset.postures[index].capturedAt = Date()
                } else {
                    preset.postures.append(CalibratedPosture(name: preset.nextPostureName(), snapshot: snapshot))
                }
            }
        }
        monitor.finishCalibrationScreen()
    }

    private func applyScreenSignature(_ signature: ScreenSignature) {
        guard let preset = library.preset(matching: signature), preset.id != library.activePresetID else { return }
        library.activePresetID = preset.id
        autoSwitchedPresetName = preset.name
    }

    public func dismissAutoSwitchNotice() {
        autoSwitchedPresetName = nil
    }

    private func updateCalibrationSuppression(_ monitorActive: Bool? = nil) {
        let active = (monitorActive ?? (monitor.isCalibrationScreenRequested || monitor.isCalibrating))
            || pendingRegistration != nil
        intervention.setCalibrationInProgress(active)
    }

    private func applySettings() {
        let resolved = resolvedSettings
        monitor.updateThresholds(resolved.thresholds)
        intervention.intensity = resolved.intensity
        forwardLiveScore(monitor.scoreBreakdown)
    }

    private func forwardLiveScore(_ breakdown: PostureScoreBreakdown) {
        intervention.updateLiveScore(
            breakdown: breakdown,
            threshold: resolvedSettings.badScoreThreshold,
            postureName: monitor.matchedPostureName,
            isTracking: monitor.isCalibrated && monitor.isCameraActive && monitor.isFaceDetected
        )
    }

    private func handleStateChange(_ state: PostureState) {
        rolloverStatsDayIfNeeded()

        let now = Date()
        switch state {
        case .good:
            if let start = nonGoodStreakStart {
                let elapsed = now.timeIntervalSince(start)
                todayBadPostureSeconds += elapsed
                if let postureID = nonGoodStreakPostureID {
                    todayBadSecondsByPosture[postureID, default: 0] += elapsed
                }
                nonGoodStreakStart = nil
                nonGoodStreakPostureID = nil
            }
        case .warning, .critical:
            if nonGoodStreakStart == nil {
                nonGoodStreakStart = now
                nonGoodStreakPostureID = monitor.matchedPostureID
            }
        }

        intervention.handle(state: state)
    }

    private func rolloverStatsDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != statsDay else { return }
        statsDay = today
        todayBadPostureSeconds = 0
        todayBadSecondsByPosture = [:]
        nonGoodStreakStart = nil
        nonGoodStreakPostureID = nil
    }
}

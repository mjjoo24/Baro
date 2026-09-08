import AppKit
import Foundation
import BaroCore

public final class InterventionController: ObservableObject {
    public var intensity: InterventionIntensity = .dim

    @Published public private(set) var isSnoozed = false {
        didSet { if oldValue && !isSnoozed { reapplyOverlay() } }
    }
    @Published public private(set) var isAutoSuppressed = false {
        didSet { if oldValue && !isAutoSuppressed { reapplyOverlay() } }
    }
    @Published public private(set) var isCalibrationSuppressed = false {
        didSet { if oldValue && !isCalibrationSuppressed { reapplyOverlay() } }
    }

    private let overlayController = OverlayWindowController()
    private var snoozeExpiryTimer: Timer?
    private var currentPostureState: PostureState = .good

    public init() {
        overlayController.onDismissRequested = { [weak self] in
            self?.snooze(for: 5 * 60)
        }
    }

    public func snooze(for duration: TimeInterval) {
        snoozeExpiryTimer?.invalidate()
        isSnoozed = true
        overlayController.hide()
        snoozeExpiryTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.isSnoozed = false
        }
    }

    public func cancelSnooze() {
        snoozeExpiryTimer?.invalidate()
        snoozeExpiryTimer = nil
        isSnoozed = false
    }

    public func updateLiveScore(
        breakdown: PostureScoreBreakdown,
        threshold: Double,
        postureName: String?,
        isTracking: Bool
    ) {
        overlayController.updateLiveScore(
            breakdown: breakdown,
            threshold: threshold,
            postureName: postureName,
            isTracking: isTracking
        )
    }

    public func setCameraConflict(_ busy: Bool) {
        isAutoSuppressed = busy
        if busy {
            overlayController.hide()
        }
    }

    public func setCalibrationInProgress(_ inProgress: Bool) {
        isCalibrationSuppressed = inProgress
        if inProgress {
            overlayController.hide()
        }
    }

    public func handle(state: PostureState) {
        currentPostureState = state
        guard !isSnoozed && !isAutoSuppressed && !isCalibrationSuppressed else { return }
        applyIntervention(for: state, isFreshTransition: true)
    }

    private func reapplyOverlay() {
        guard !isSnoozed && !isAutoSuppressed && !isCalibrationSuppressed else { return }
        applyIntervention(for: currentPostureState, isFreshTransition: false)
    }

    private func applyIntervention(for state: PostureState, isFreshTransition: Bool) {
        switch state {
        case .good:
            overlayController.hide()

        case .warning:
            overlayController.hide()

        case .critical:
            switch intensity {
            case .menuBarOnly:
                overlayController.hide()
            case .dim:
                overlayController.show(style: .dim)
            case .blur:
                overlayController.show(style: .blur)
            case .turnOffDisplay:
                overlayController.show(style: .dim)
                if isFreshTransition {
                    turnOffDisplay()
                }
            }
        }
    }

    private func turnOffDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
}

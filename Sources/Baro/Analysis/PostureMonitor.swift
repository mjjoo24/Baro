import AppKit
import Combine
import CoreImage
import CoreVideo
import Foundation
import BaroCore

public final class PostureMonitor: ObservableObject, @unchecked Sendable {
    @Published public private(set) var state: PostureState = .good
    @Published public private(set) var currentScore: Double = 0
    @Published public private(set) var scoreBreakdown: PostureScoreBreakdown = .zero
    @Published public private(set) var matchedPostureName: String?
    @Published public private(set) var matchedPostureID: UUID?
    @Published public private(set) var isPostureUnmeasurable: Bool = false
    @Published public private(set) var isCalibrated: Bool = false
    @Published public private(set) var isCameraActive: Bool = false
    @Published public private(set) var isCalibrating: Bool = false
    @Published public private(set) var isCameraPermissionDenied: Bool = false
    @Published public private(set) var calibrationProgress: Double = 0
    @Published public private(set) var previewImage: NSImage?
    @Published public private(set) var isFaceDetected: Bool = false
    @Published public private(set) var isCameraBusyElsewhere: Bool = false
    @Published public private(set) var isCalibrationScreenRequested: Bool = false
    @Published public private(set) var calibrationAbortReason: CalibrationAbortReason?

    public var onStateChange: ((PostureState) -> Void)?
    public var onCalibrationCaptured: ((FaceLandmarkSnapshot) -> Void)?

    private let captureManager: CaptureManager
    private let extractor = VisionFaceLandmarkExtractor()
    private let stateMachine: PostureStateMachine
    private var matcher: PostureMatcher

    private let stateQueue = DispatchQueue(label: "com.baro.monitor.state")
    private var postures: [CalibratedPosture] = []
    private var calibrationSamples: [FaceLandmarkSnapshot] = []
    private let calibrationSampleTarget = 8
    private let stabilityChecker = CalibrationStabilityChecker()
    private var calibrationReference: FaceLandmarkSnapshot?
    private var calibrationMissingFrames = 0

    private var calibratingInternal = false
    private var previewModeInternal = true

    public init(
        postures: [CalibratedPosture] = [],
        thresholds: PostureThresholds = .default,
        scoringWeights: PostureScoringWeights = .default,
        captureManager: CaptureManager = CaptureManager()
    ) {
        self.stateMachine = PostureStateMachine(thresholds: thresholds)
        self.matcher = PostureMatcher(scorer: PostureScorer(weights: scoringWeights))
        self.captureManager = captureManager
        self.postures = postures
        self.isCalibrated = !postures.isEmpty
        self.previewModeInternal = postures.isEmpty

        captureManager.onFrame = { [weak self] pixelBuffer in
            self?.handleFrame(pixelBuffer)
        }

        captureManager.onAuthorizationChange = { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCameraActive = (status == .authorized)
                self.isCameraPermissionDenied = (status == .denied || status == .restricted)
            }
        }

        captureManager.onBusyElsewhereChange = { [weak self] busy in
            DispatchQueue.main.async {
                self?.isCameraBusyElsewhere = busy
            }
        }
    }

    public func start() {
        captureManager.start()
    }

    public func stop() {
        captureManager.stop()
        DispatchQueue.main.async { self.isCameraActive = false }
    }

    public func updatePostures(_ postures: [CalibratedPosture]) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.postures = postures
            self.stateMachine.reset()
            if postures.isEmpty {
                self.previewModeInternal = true
            }
            DispatchQueue.main.async {
                self.isCalibrated = !postures.isEmpty
                if postures.isEmpty {
                    self.matchedPostureName = nil
                    self.matchedPostureID = nil
                    self.scoreBreakdown = .zero
                    self.currentScore = 0
                }
            }
        }
    }

    public func requestCalibrationScreen() {
        if !isCameraActive {
            start()
        }
        stateQueue.async { [weak self] in
            self?.previewModeInternal = true
        }
        DispatchQueue.main.async {
            self.isCalibrationScreenRequested = true
        }
    }

    public func cancelCalibrationScreenRequest() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.calibratingInternal = false
            self.calibrationSamples.removeAll()
            self.calibrationReference = nil
            self.calibrationMissingFrames = 0
            self.previewModeInternal = self.postures.isEmpty
            DispatchQueue.main.async {
                self.isCalibrationScreenRequested = false
                self.isCalibrating = false
                self.calibrationProgress = 0
                self.calibrationAbortReason = nil
                self.previewImage = nil
            }
        }
    }

    public func beginCalibration() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.calibrationSamples.removeAll()
            self.calibrationReference = nil
            self.calibrationMissingFrames = 0
            self.calibratingInternal = true
            self.previewModeInternal = true
            DispatchQueue.main.async {
                self.isCalibrating = true
                self.calibrationProgress = 0
                self.calibrationAbortReason = nil
            }
        }
    }

    public func updateThresholds(_ thresholds: PostureThresholds) {
        stateQueue.async { [weak self] in
            self?.stateMachine.thresholds = thresholds
        }
    }

    public func updateScoringWeights(_ weights: PostureScoringWeights) {
        stateQueue.async { [weak self] in
            self?.matcher.scorer.weights = weights
        }
    }

    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        let snapshot = extractor.extract(from: pixelBuffer)
        let now = Date()

        stateQueue.async { [weak self] in
            guard let self else { return }

            let detected = snapshot != nil
            if self.previewModeInternal {
                let preview = Self.makePreviewImage(from: pixelBuffer)
                DispatchQueue.main.async {
                    self.previewImage = preview
                    self.isFaceDetected = detected
                }
            } else {
                DispatchQueue.main.async {
                    self.isFaceDetected = detected
                }
            }

            guard let snapshot else {
                if self.calibratingInternal {
                    self.calibrationMissingFrames += 1
                    if self.stabilityChecker.hasLostFace(consecutiveMissingFrames: self.calibrationMissingFrames) {
                        self.abortCalibration(reason: .faceLost)
                        return
                    }
                }
                self.stateMachine.recordFaceNotDetected(at: now)
                return
            }

            if self.calibratingInternal {
                self.calibrationMissingFrames = 0

                if let reference = self.calibrationReference {
                    if self.stabilityChecker.hasMoved(reference: reference, sample: snapshot) {
                        self.abortCalibration(reason: .moved)
                        return
                    }
                } else {
                    self.calibrationReference = snapshot
                }

                self.calibrationSamples.append(snapshot)
                let progress = min(1, Double(self.calibrationSamples.count) / Double(self.calibrationSampleTarget))
                DispatchQueue.main.async { self.calibrationProgress = progress }
                if self.calibrationSamples.count >= self.calibrationSampleTarget {
                    self.finishCalibration(with: self.calibrationSamples)
                }
                return
            }

            guard let match = self.matcher.bestMatch(postures: self.postures, current: snapshot) else { return }

            if self.matcher.isUnmeasurable(match) {
                self.stateMachine.recordFaceNotDetected(at: now)
                DispatchQueue.main.async {
                    self.isPostureUnmeasurable = true
                    self.scoreBreakdown = match.breakdown
                    self.currentScore = match.breakdown.total
                    self.matchedPostureName = match.postureName
                    self.matchedPostureID = match.postureID
                }
                return
            }

            let newState = self.stateMachine.update(score: match.breakdown.total, at: now)

            DispatchQueue.main.async {
                self.isPostureUnmeasurable = false
                self.currentScore = match.breakdown.total
                self.scoreBreakdown = match.breakdown
                self.matchedPostureName = match.postureName
                self.matchedPostureID = match.postureID
                if self.state != newState {
                    self.state = newState
                    self.onStateChange?(newState)
                }
            }
        }
    }

    private func abortCalibration(reason: CalibrationAbortReason) {
        calibratingInternal = false
        calibrationSamples.removeAll()
        calibrationReference = nil
        calibrationMissingFrames = 0
        DispatchQueue.main.async {
            self.isCalibrating = false
            self.calibrationProgress = 0
            self.calibrationAbortReason = reason
            self.isCalibrationScreenRequested = true
        }
    }

    private func finishCalibration(with samples: [FaceLandmarkSnapshot]) {
        calibratingInternal = false
        calibrationReference = nil
        calibrationMissingFrames = 0
        guard let averaged = FaceLandmarkSnapshot.average(samples) else {
            DispatchQueue.main.async { self.isCalibrating = false }
            return
        }
        stateMachine.reset()
        DispatchQueue.main.async {
            self.isCalibrating = false
            self.calibrationProgress = 1
            self.calibrationAbortReason = nil
            self.onCalibrationCaptured?(averaged)
        }
    }

    public func finishCalibrationScreen() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.previewModeInternal = false
            DispatchQueue.main.async {
                self.isCalibrationScreenRequested = false
                self.calibrationProgress = 0
                self.previewImage = nil
            }
        }
    }

    private static func makePreviewImage(from pixelBuffer: CVPixelBuffer) -> NSImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let mirrored = ciImage
            .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            .transformed(by: CGAffineTransform(translationX: ciImage.extent.width, y: 0))
        let rep = NSCIImageRep(ciImage: mirrored)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

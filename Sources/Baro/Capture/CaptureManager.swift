import AVFoundation
import Foundation
import os.log

private let logger = Logger(subsystem: "com.baro.app", category: "CaptureManager")

public enum CameraAuthorizationState: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public final class CaptureManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    public var targetFramesPerSecond: Double = 1.5

    public var onFrame: (@Sendable (CVPixelBuffer) -> Void)?

    public var onAuthorizationChange: (@Sendable (CameraAuthorizationState) -> Void)?

    public var onBusyElsewhereChange: (@Sendable (Bool) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.baro.capture.session")
    private let videoOutputQueue = DispatchQueue(label: "com.baro.capture.output")
    private var lastFrameTime: CFAbsoluteTime = 0
    private(set) var isRunning = false
    private var busyObservation: NSKeyValueObservation?

    public override init() {
        super.init()
    }

    public static func currentAuthorizationState() -> CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    public static func requestAuthorization() async -> CameraAuthorizationState {
        switch currentAuthorizationState() {
        case .authorized, .denied, .restricted:
            return currentAuthorizationState()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        }
    }

    public func start() {
        Task { [weak self] in
            let status = await CaptureManager.requestAuthorization()
            self?.onAuthorizationChange?(status)
            guard status == .authorized else {
                logger.warning("카메라 권한이 없어 캡처를 시작하지 않음: \(String(describing: status))")
                return
            }
            self?.sessionQueue.async {
                self?.configureAndStartSession()
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.busyObservation?.invalidate()
            self.busyObservation = nil
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            self.isRunning = false
        }
    }

    private func configureAndStartSession() {
        guard CaptureManager.currentAuthorizationState() == .authorized else {
            logger.warning("카메라 권한이 없어 캡처 세션을 시작하지 않음")
            return
        }
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .low

        var configurationSucceeded = false
        defer {
            session.commitConfiguration()
            if configurationSucceeded {
                session.startRunning()
                isRunning = true
            }
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
            logger.error("사용 가능한 카메라 디바이스를 찾지 못함")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.inputs.forEach { session.removeInput($0) }
                session.addInput(input)
            }
        } catch {
            logger.error("카메라 입력 구성 실패: \(String(describing: error))")
            return
        }

        busyObservation?.invalidate()
        busyObservation = device.observe(\.isInUseByAnotherApplication, options: [.initial, .new]) { [weak self] observedDevice, _ in
            self?.onBusyElsewhereChange?(observedDevice.isInUseByAnotherApplication)
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(output) {
            session.outputs.forEach { session.removeOutput($0) }
            session.addOutput(output)
        }

        configurationSucceeded = true
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        let minInterval = 1.0 / max(targetFramesPerSecond, 0.1)
        guard now - lastFrameTime >= minInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}

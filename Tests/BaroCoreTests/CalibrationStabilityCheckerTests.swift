import XCTest
@testable import BaroCore

final class CalibrationStabilityCheckerTests: XCTestCase {
    private let reference = FaceLandmarkSnapshot(
        faceBoundingBoxWidth: 0.20,
        faceBoundingBoxHeight: 0.25,
        leftEyeX: 0.42,
        leftEyeY: 0.40,
        rightEyeX: 0.58,
        rightEyeY: 0.40,
        noseTipX: 0.50,
        noseTipY: 0.45
    )

    func test_identicalSample_isStable() {
        let checker = CalibrationStabilityChecker()
        XCTAssertFalse(checker.hasMoved(reference: reference, sample: reference))
        XCTAssertEqual(checker.movementRatio(reference: reference, sample: reference), 0, accuracy: 0.0001)
    }

    func test_smallJitter_isStable() {
        var sample = reference
        sample.leftEyeY += 0.01
        sample.rightEyeY += 0.01
        sample.faceBoundingBoxWidth += 0.005
        let checker = CalibrationStabilityChecker()
        XCTAssertFalse(checker.hasMoved(reference: reference, sample: sample))
    }

    func test_movingCloser_isMovement() {
        var sample = reference
        sample.faceBoundingBoxWidth = 0.24
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_movingAway_isMovement() {
        var sample = reference
        sample.faceBoundingBoxWidth = 0.16
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_headDroppingDown_isMovement() {
        var sample = reference
        sample.leftEyeY += 0.08
        sample.rightEyeY += 0.08
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_sittingUp_isMovement() {
        var sample = reference
        sample.leftEyeY -= 0.08
        sample.rightEyeY -= 0.08
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_lateralShift_isMovement() {
        var sample = reference
        sample.leftEyeX += 0.1
        sample.rightEyeX += 0.1
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_tiltingHead_isMovement() {
        var sample = reference
        sample.rightEyeY = reference.leftEyeY + (reference.rightEyeX - reference.leftEyeX) * tan(12 * .pi / 180)
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_turningHead_isMovement() {
        var sample = reference
        sample.noseTipX += 0.05 * reference.faceBoundingBoxWidth
        XCTAssertTrue(CalibrationStabilityChecker().hasMoved(reference: reference, sample: sample))
    }

    func test_faceLossBelowLimit_doesNotAbort() {
        let checker = CalibrationStabilityChecker(faceLossFrameLimit: 3)
        XCTAssertFalse(checker.hasLostFace(consecutiveMissingFrames: 2))
    }

    func test_faceLossAtLimit_aborts() {
        let checker = CalibrationStabilityChecker(faceLossFrameLimit: 3)
        XCTAssertTrue(checker.hasLostFace(consecutiveMissingFrames: 3))
    }
}

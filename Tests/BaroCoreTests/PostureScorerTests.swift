import XCTest
@testable import BaroCore

final class PostureScorerTests: XCTestCase {
    private let baseline = FaceLandmarkSnapshot(
        faceBoundingBoxWidth: 0.20,
        faceBoundingBoxHeight: 0.25,
        leftEyeX: 0.42,
        leftEyeY: 0.40,
        rightEyeX: 0.58,
        rightEyeY: 0.40,
        noseTipX: 0.50,
        noseTipY: 0.45
    )

    private func tilted(_ degrees: Double) -> FaceLandmarkSnapshot {
        var snapshot = baseline
        let dx = snapshot.rightEyeX - snapshot.leftEyeX
        snapshot.rightEyeY = snapshot.leftEyeY + dx * tan(degrees * .pi / 180)
        return snapshot
    }

    private func turned(_ ratio: Double) -> FaceLandmarkSnapshot {
        var snapshot = baseline
        snapshot.noseTipX += ratio * snapshot.faceBoundingBoxWidth
        return snapshot
    }

    func test_identicalToBaseline_scoresZero() {
        let scorer = PostureScorer()
        let score = scorer.score(baseline: baseline, current: baseline)
        XCTAssertEqual(score, 0, accuracy: 0.0001)
    }

    func test_fartherFromCamera_doesNotIncreaseScore() {
        var current = baseline
        current.faceBoundingBoxWidth = 0.15
        let scorer = PostureScorer()
        let score = scorer.score(baseline: baseline, current: current)
        XCTAssertEqual(score, 0, accuracy: 0.0001)
    }

    func test_movingCloserToCamera_increasesScoreToMax() {
        var current = baseline
        current.faceBoundingBoxWidth = 0.26
        let scorer = PostureScorer()
        let score = scorer.score(baseline: baseline, current: current)
        XCTAssertEqual(score, 100, accuracy: 0.5)
    }

    func test_headDroppingDown_increasesScoreToMax() {
        var current = baseline
        current.leftEyeY = baseline.leftEyeY + 0.15
        current.rightEyeY = baseline.rightEyeY + 0.15
        let scorer = PostureScorer()
        let score = scorer.score(baseline: baseline, current: current)
        XCTAssertEqual(score, 100, accuracy: 0.5)
    }

    func test_headTilt_increasesScoreToMax() {
        let score = PostureScorer().score(baseline: baseline, current: tilted(30))
        XCTAssertEqual(score, 100, accuracy: 1.0)
    }

    func test_headTurn_scoresTurnWithoutTilt() {
        let breakdown = PostureScorer().scoreBreakdown(baseline: baseline, current: turned(0.12))
        XCTAssertEqual(breakdown.turn, 100, accuracy: 0.5)
        XCTAssertEqual(breakdown.tilt, 0, accuracy: 0.0001)
    }

    func test_headTilt_scoresTiltWithoutTurn() {
        let breakdown = PostureScorer().scoreBreakdown(baseline: baseline, current: tilted(30))
        XCTAssertEqual(breakdown.tilt, 100, accuracy: 0.5)
        XCTAssertEqual(breakdown.turn, 0, accuracy: 0.0001)
    }

    func test_turnIsMeasuredFromNoseOffsetNotEyeLine() {
        var current = baseline
        current.leftEyeY = baseline.leftEyeY + 0.02
        current.rightEyeY = baseline.rightEyeY - 0.02
        let breakdown = PostureScorer().scoreBreakdown(baseline: baseline, current: current)
        XCTAssertEqual(breakdown.turn, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(breakdown.tilt, 0)
    }

    func test_turnAndTilt_accumulateIndependently() {
        var current = tilted(15)
        current.noseTipX += 0.06 * baseline.faceBoundingBoxWidth
        let breakdown = PostureScorer().scoreBreakdown(baseline: baseline, current: current)
        XCTAssertEqual(breakdown.tilt, 50, accuracy: 0.5)
        XCTAssertEqual(breakdown.turn, 50, accuracy: 0.5)
        XCTAssertEqual(breakdown.total, 100, accuracy: 1.0)
    }

    func test_combinedBadPosture_sumsIndependentComponentsAndClamps() {
        var current = baseline
        current.faceBoundingBoxWidth = 0.26
        current.leftEyeY = baseline.leftEyeY + 0.15
        current.rightEyeY = baseline.rightEyeY + 0.15
        let scorer = PostureScorer()
        let score = scorer.score(baseline: baseline, current: current)
        XCTAssertEqual(score, 100, accuracy: 0.5)
    }

    func test_partialBadPosture_sumsComponents() {
        var current = baseline
        current.faceBoundingBoxWidth = 0.203
        let scorer = PostureScorer()
        let breakdown = scorer.scoreBreakdown(baseline: baseline, current: current)
        XCTAssertEqual(
            breakdown.total,
            breakdown.forward + breakdown.downward + breakdown.tilt + breakdown.turn,
            accuracy: 0.0001
        )
        XCTAssertLessThan(breakdown.total, 100)
    }

    func test_scoreNeverExceeds100() {
        var current = baseline
        current.faceBoundingBoxWidth = 1.0
        current.leftEyeY = 0.99
        current.rightEyeY = 0.99
        let scorer = PostureScorer()
        let score = scorer.score(baseline: baseline, current: current)
        XCTAssertLessThanOrEqual(score, 100)
    }

    func test_zeroBaselineWidth_doesNotCrashOrProduceNaN() {
        var zeroBaseline = baseline
        zeroBaseline.faceBoundingBoxWidth = 0
        let scorer = PostureScorer()
        let score = scorer.score(baseline: zeroBaseline, current: baseline)
        XCTAssertFalse(score.isNaN)
    }

    func test_scoreBreakdown_exposesEachComponentIndependently() {
        var current = baseline
        current.faceBoundingBoxWidth = 0.26
        current.leftEyeY = baseline.leftEyeY + 0.15
        current.rightEyeY = baseline.rightEyeY + 0.15

        let scorer = PostureScorer()
        let breakdown = scorer.scoreBreakdown(baseline: baseline, current: current)

        XCTAssertEqual(breakdown.forward, 100, accuracy: 0.5)
        XCTAssertEqual(breakdown.downward, 100, accuracy: 0.5)
        XCTAssertEqual(breakdown.tilt, 0, accuracy: 0.5)
        XCTAssertEqual(breakdown.total, 100, accuracy: 0.5)
    }

    func test_scoreBreakdown_identicalToBaseline_allZero() {
        let scorer = PostureScorer()
        let breakdown = scorer.scoreBreakdown(baseline: baseline, current: baseline)
        XCTAssertEqual(breakdown, .zero)
    }
}

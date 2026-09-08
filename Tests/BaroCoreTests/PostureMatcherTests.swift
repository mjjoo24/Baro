import XCTest
@testable import BaroCore

final class PostureMatcherTests: XCTestCase {
    private let frontal = FaceLandmarkSnapshot(
        faceBoundingBoxWidth: 0.20,
        faceBoundingBoxHeight: 0.25,
        leftEyeX: 0.42,
        leftEyeY: 0.40,
        rightEyeX: 0.58,
        rightEyeY: 0.40,
        noseTipX: 0.50,
        noseTipY: 0.45
    )

    private func turned(_ ratio: Double, from base: FaceLandmarkSnapshot? = nil) -> FaceLandmarkSnapshot {
        var snapshot = base ?? frontal
        snapshot.noseTipX += ratio * snapshot.faceBoundingBoxWidth
        return snapshot
    }

    private func slouched(_ drop: Double) -> FaceLandmarkSnapshot {
        var snapshot = frontal
        snapshot.leftEyeY += drop
        snapshot.rightEyeY += drop
        return snapshot
    }

    func test_noPostures_hasNoMatch() {
        XCTAssertNil(PostureMatcher().bestMatch(postures: [], current: frontal))
    }

    func test_singlePosture_matchesIt() {
        let posture = CalibratedPosture(name: "정면", snapshot: frontal)
        let match = PostureMatcher().bestMatch(postures: [posture], current: frontal)
        XCTAssertEqual(match?.postureID, posture.id)
        XCTAssertEqual(match?.breakdown.total ?? -1, 0, accuracy: 0.0001)
    }

    func test_sideMonitorPosture_scoresZeroWhenRegistered() {
        let side = turned(0.12)
        let postures = [
            CalibratedPosture(name: "정면", snapshot: frontal),
            CalibratedPosture(name: "옆 모니터", snapshot: side)
        ]
        let match = PostureMatcher().bestMatch(postures: postures, current: side)
        XCTAssertEqual(match?.postureName, "옆 모니터")
        XCTAssertEqual(match?.breakdown.total ?? -1, 0, accuracy: 0.0001)
    }

    func test_sideMonitorPosture_scoresMaxWhenNotRegistered() {
        let postures = [CalibratedPosture(name: "정면", snapshot: frontal)]
        let match = PostureMatcher().bestMatch(postures: postures, current: turned(0.12))
        XCTAssertEqual(match?.breakdown.turn ?? -1, 100, accuracy: 0.5)
    }

    func test_matchPicksLowestScoringPosture() {
        let postures = [
            CalibratedPosture(name: "정면", snapshot: frontal),
            CalibratedPosture(name: "옆 모니터", snapshot: turned(0.12))
        ]
        let match = PostureMatcher().bestMatch(postures: postures, current: turned(0.10))
        XCTAssertEqual(match?.postureName, "옆 모니터")
    }

    func test_slouchIsStillDetectedInRegisteredSidePosture() {
        var sideSlouched = turned(0.12)
        sideSlouched.leftEyeY += 0.15
        sideSlouched.rightEyeY += 0.15
        let postures = [
            CalibratedPosture(name: "정면", snapshot: frontal),
            CalibratedPosture(name: "옆 모니터", snapshot: turned(0.12))
        ]
        let match = PostureMatcher().bestMatch(postures: postures, current: sideSlouched)
        XCTAssertEqual(match?.postureName, "옆 모니터")
        XCTAssertGreaterThanOrEqual(match!.breakdown.total, 100)
    }

    func test_unmeasurableWhenTurnSaturates() {
        let postures = [CalibratedPosture(name: "정면", snapshot: frontal)]
        let matcher = PostureMatcher()
        let match = matcher.bestMatch(postures: postures, current: turned(0.30))!
        XCTAssertTrue(matcher.isUnmeasurable(match))
    }

    func test_measurableWhenTurnIsSmall() {
        let postures = [CalibratedPosture(name: "정면", snapshot: frontal)]
        let matcher = PostureMatcher()
        let match = matcher.bestMatch(postures: postures, current: turned(0.03))!
        XCTAssertFalse(matcher.isUnmeasurable(match))
    }

    func test_registrationWarning_noneForFirstPosture() {
        XCTAssertNil(PostureMatcher().registrationWarning(candidate: frontal, existing: []))
    }

    func test_registrationWarning_duplicate() {
        let existing = [CalibratedPosture(name: "정면", snapshot: frontal)]
        var almostSame = frontal
        almostSame.leftEyeY += 0.005
        almostSame.rightEyeY += 0.005
        XCTAssertEqual(
            PostureMatcher().registrationWarning(candidate: almostSame, existing: existing),
            .duplicate(existingName: "정면")
        )
    }

    func test_registrationWarning_worseThanRegistered() {
        let existing = [CalibratedPosture(name: "정면", snapshot: frontal)]
        let warning = PostureMatcher().registrationWarning(candidate: slouched(0.09), existing: existing)
        guard case .worseThanRegistered(let name, let score)? = warning else {
            return XCTFail("기대한 경고가 아님: \(String(describing: warning))")
        }
        XCTAssertEqual(name, "정면")
        XCTAssertGreaterThanOrEqual(score, 35)
    }

    func test_registrationWarning_noneForLegitimateSidePosture() {
        let existing = [CalibratedPosture(name: "정면", snapshot: frontal)]
        var side = turned(0.12)
        side.faceBoundingBoxWidth = 0.185
        XCTAssertNil(PostureMatcher().registrationWarning(candidate: side, existing: existing))
    }

    func test_registrationWarning_stillFlagsSlouchInSideDirection() {
        let existing = [CalibratedPosture(name: "정면", snapshot: frontal)]
        var sideSlouched = turned(0.12)
        sideSlouched.leftEyeY += 0.09
        sideSlouched.rightEyeY += 0.09
        guard case .worseThanRegistered? = PostureMatcher().registrationWarning(candidate: sideSlouched, existing: existing) else {
            return XCTFail("옆을 보더라도 숙인 자세는 경고해야 함")
        }
    }
}

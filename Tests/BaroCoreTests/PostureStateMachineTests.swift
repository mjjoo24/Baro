import XCTest
@testable import BaroCore

final class PostureStateMachineTests: XCTestCase {
    private let thresholds = PostureThresholds(
        badScoreThreshold: 55,
        warningDuration: 10,
        criticalDuration: 30,
        recoveryDebounce: 2,
        faceLossResetAfter: 15
    )

    private func makeSUT() -> PostureStateMachine {
        PostureStateMachine(thresholds: thresholds)
    }

    func test_initialState_isGood() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .good)
    }

    func test_goodScore_staysGood() {
        let sut = makeSUT()
        let base = Date()
        let state = sut.update(score: 10, at: base)
        XCTAssertEqual(state, .good)
    }

    func test_badScore_shortDuration_staysGood() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        let state = sut.update(score: 80, at: base.addingTimeInterval(5))
        XCTAssertEqual(state, .good, "warningDuration(10s) 미만이면 아직 Good 상태여야 한다")
    }

    func test_badScore_sustainedPastWarningDuration_entersWarning() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        let state = sut.update(score: 80, at: base.addingTimeInterval(11))
        XCTAssertEqual(state, .warning)
    }

    func test_badScore_sustainedPastCriticalDuration_entersCritical() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        _ = sut.update(score: 80, at: base.addingTimeInterval(11))
        let state = sut.update(score: 80, at: base.addingTimeInterval(31))
        XCTAssertEqual(state, .critical)
    }

    func test_recoveringToGoodScore_afterDebounce_returnsToGood() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        _ = sut.update(score: 80, at: base.addingTimeInterval(31))
        _ = sut.update(score: 10, at: base.addingTimeInterval(31.5))
        let stillCritical = sut.state
        XCTAssertEqual(stillCritical, .critical, "recoveryDebounce(2s) 전에는 상태가 유지되어야 한다")

        let recovered = sut.update(score: 10, at: base.addingTimeInterval(33.5))
        XCTAssertEqual(recovered, .good)
    }

    func test_briefGoodBlip_duringBadStreak_doesNotResetBadStreakPrematurely() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        _ = sut.update(score: 80, at: base.addingTimeInterval(9))
        _ = sut.update(score: 10, at: base.addingTimeInterval(9.5))
        let state = sut.update(score: 80, at: base.addingTimeInterval(9.8))
        XCTAssertEqual(state, .good)
    }

    func test_faceNotDetected_withinResetWindow_preservesStreak() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        sut.recordFaceNotDetected(at: base.addingTimeInterval(5))
        let state = sut.update(score: 80, at: base.addingTimeInterval(11))
        XCTAssertEqual(state, .warning, "짧은 얼굴 미검출은 기존 스트릭을 유지해야 한다")
    }

    func test_faceNotDetected_beyondResetWindow_resetsStreak() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        sut.recordFaceNotDetected(at: base.addingTimeInterval(20))
        let state = sut.update(score: 80, at: base.addingTimeInterval(21))
        XCTAssertEqual(state, .good, "긴 얼굴 미검출 이후에는 스트릭이 리셋되어야 한다")
    }

    func test_reset_returnsToGoodAndClearsStreaks() {
        let sut = makeSUT()
        let base = Date()
        sut.update(score: 80, at: base)
        _ = sut.update(score: 80, at: base.addingTimeInterval(31))
        XCTAssertEqual(sut.state, .critical)

        sut.reset()
        XCTAssertEqual(sut.state, .good)

        let state = sut.update(score: 80, at: base.addingTimeInterval(31.1))
        XCTAssertEqual(state, .good)
    }
}

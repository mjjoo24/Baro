import XCTest
@testable import BaroCore

final class InterventionParametersTests: XCTestCase {
    private let base = InterventionParameters(
        badScoreThreshold: 45,
        warningDuration: 3,
        criticalDelayAfterWarning: 5,
        intensity: .dim
    )

    func test_noOverrides_keepsBase() {
        XCTAssertEqual(base.applying(nil), base)
        XCTAssertEqual(base.applying(PresetOverrides()), base)
    }

    func test_partialOverride_replacesOnlyGivenFields() {
        let resolved = base.applying(PresetOverrides(badScoreThreshold: 65))
        XCTAssertEqual(resolved.badScoreThreshold, 65)
        XCTAssertEqual(resolved.warningDuration, 3)
        XCTAssertEqual(resolved.criticalDelayAfterWarning, 5)
        XCTAssertEqual(resolved.intensity, .dim)
    }

    func test_fullOverride_replacesEverything() {
        let resolved = base.applying(PresetOverrides(
            badScoreThreshold: 65,
            warningDuration: 8,
            criticalDelayAfterWarning: 15,
            intensity: .menuBarOnly
        ))
        XCTAssertEqual(resolved.badScoreThreshold, 65)
        XCTAssertEqual(resolved.warningDuration, 8)
        XCTAssertEqual(resolved.criticalDelayAfterWarning, 15)
        XCTAssertEqual(resolved.intensity, .menuBarOnly)
    }

    func test_thresholdsAddWarningAndDelay() {
        let resolved = base.applying(PresetOverrides(warningDuration: 8, criticalDelayAfterWarning: 15))
        XCTAssertEqual(resolved.thresholds.warningDuration, 8)
        XCTAssertEqual(resolved.thresholds.criticalDuration, 23)
        XCTAssertEqual(resolved.thresholds.badScoreThreshold, 45)
    }

    func test_emptyOverridesAreConsideredEmpty() {
        XCTAssertTrue(PresetOverrides().isEmpty)
        XCTAssertFalse(PresetOverrides(badScoreThreshold: 50).isEmpty)
    }
}

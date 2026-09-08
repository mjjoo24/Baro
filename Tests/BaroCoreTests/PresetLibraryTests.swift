import XCTest
@testable import BaroCore

private func makeSnapshot(width: Double = 0.20, eyeY: Double = 0.40, noseX: Double = 0.50) -> FaceLandmarkSnapshot {
    FaceLandmarkSnapshot(
        faceBoundingBoxWidth: width,
        faceBoundingBoxHeight: 0.25,
        leftEyeX: 0.42,
        leftEyeY: eyeY,
        rightEyeX: 0.58,
        rightEyeY: eyeY,
        noseTipX: noseX,
        noseTipY: 0.45
    )
}

private final class MemoryPersistence: PresetPersisting, @unchecked Sendable {
    var stored: PresetLibrary?
    func load() -> PresetLibrary? { stored }
    func save(_ library: PresetLibrary) throws { stored = library }
}

final class PresetLibraryTests: XCTestCase {
    func test_defaultLibrary_hasOneActivePreset() {
        let library = PresetLibrary.makeDefault()
        XCTAssertEqual(library.presets.count, 1)
        XCTAssertEqual(library.activePreset.id, library.presets[0].id)
        XCTAssertFalse(library.isCalibrated)
    }

    func test_addPreset_becomesActive() {
        var library = PresetLibrary.makeDefault()
        let id = library.addPreset(name: "사무실")
        XCTAssertEqual(library.presets.count, 2)
        XCTAssertEqual(library.activePresetID, id)
    }

    func test_addPreset_stopsAtMax() {
        var library = PresetLibrary.makeDefault()
        while library.canAddPreset {
            XCTAssertNotNil(library.addPreset())
        }
        XCTAssertEqual(library.presets.count, PresetLibrary.maxPresets)
        XCTAssertNil(library.addPreset())
    }

    func test_duplicatePreset_copiesPosturesWithNewIdentity() {
        var library = PresetLibrary.makeDefault(postures: [CalibratedPosture(name: "정면", snapshot: makeSnapshot())])
        let sourceID = library.activePresetID
        let copyID = library.duplicatePreset(sourceID)
        XCTAssertNotNil(copyID)
        let source = library.presets.first { $0.id == sourceID }!
        let copy = library.presets.first { $0.id == copyID }!
        XCTAssertEqual(copy.postures.count, 1)
        XCTAssertEqual(copy.postures[0].snapshot, source.postures[0].snapshot)
        XCTAssertNotEqual(copy.postures[0].id, source.postures[0].id)
        XCTAssertEqual(copy.name, "기본 사본")
    }

    func test_duplicatePreset_doesNotInheritScreenBinding() {
        var library = PresetLibrary.makeDefault()
        library.updateActivePreset { $0.screenSignature = ScreenSignature(displaySizes: ["1440x900"]) }
        let copyID = library.duplicatePreset(library.activePresetID)!
        XCTAssertNil(library.presets.first { $0.id == copyID }!.screenSignature)
    }

    func test_removePreset_keepsAtLeastOne() {
        var library = PresetLibrary.makeDefault()
        library.removePreset(library.activePresetID)
        XCTAssertEqual(library.presets.count, 1)
    }

    func test_removeActivePreset_movesActiveToSurvivor() {
        var library = PresetLibrary.makeDefault()
        let secondID = library.addPreset(name: "두번째")!
        library.removePreset(secondID)
        XCTAssertEqual(library.presets.count, 1)
        XCTAssertNotEqual(library.activePresetID, secondID)
    }

    func test_postureLimitPerPreset() {
        var preset = PosturePreset(name: "테스트")
        for _ in 0..<PosturePreset.maxPostures {
            XCTAssertTrue(preset.canAddPosture)
            preset.postures.append(CalibratedPosture(name: preset.nextPostureName(), snapshot: makeSnapshot()))
        }
        XCTAssertFalse(preset.canAddPosture)
    }

    func test_presetMatchingScreenSignature() {
        var library = PresetLibrary.makeDefault()
        let signature = ScreenSignature(displaySizes: ["1440x900", "2560x1440"])
        let officeID = library.addPreset(name: "사무실", screenSignature: signature)!
        XCTAssertEqual(library.preset(matching: signature)?.id, officeID)
        XCTAssertNil(library.preset(matching: ScreenSignature(displaySizes: ["1440x900"])))
    }

    func test_screenSignatureIgnoresDisplayOrder() {
        let a = ScreenSignature(displaySizes: ["2560x1440", "1440x900"])
        let b = ScreenSignature(displaySizes: ["1440x900", "2560x1440"])
        XCTAssertEqual(a, b)
    }

    func test_persistenceRoundTrip() throws {
        let persistence = MemoryPersistence()
        let store = PresetStore(persistence: persistence)
        var library = store.library
        library.addPreset(name: "사무실")
        store.replace(with: library)

        let reloaded = PresetStore(persistence: persistence)
        XCTAssertEqual(reloaded.library.presets.count, 2)
        XCTAssertEqual(reloaded.library.activePreset.name, "사무실")
    }

    func test_legacyCalibrationFileMigratesIntoDefaultPreset() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacyURL = dir.appendingPathComponent("calibration.json")
        let presetsURL = dir.appendingPathComponent("presets.json")
        let snapshot = makeSnapshot()
        try JSONEncoder().encode(snapshot).write(to: legacyURL)

        let persistence = FilePresetPersistence(fileURL: presetsURL, legacyFileURL: legacyURL)
        let library = persistence.load()

        XCTAssertEqual(library?.presets.count, 1)
        XCTAssertEqual(library?.activePostures.count, 1)
        XCTAssertEqual(library?.activePostures[0].snapshot, snapshot)
        XCTAssertEqual(library?.schemaVersion, PresetLibrary.currentSchemaVersion)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: presetsURL.path))
    }

    func test_missingFiles_loadReturnsNil() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let persistence = FilePresetPersistence(
            fileURL: dir.appendingPathComponent("presets.json"),
            legacyFileURL: dir.appendingPathComponent("calibration.json")
        )
        XCTAssertNil(persistence.load())
    }
}

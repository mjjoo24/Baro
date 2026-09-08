import Foundation

public struct PresetLibrary: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 2
    public static let maxPresets = 8

    public var schemaVersion: Int
    public var presets: [PosturePreset]
    public var activePresetID: UUID

    public init(schemaVersion: Int = PresetLibrary.currentSchemaVersion, presets: [PosturePreset], activePresetID: UUID) {
        self.schemaVersion = schemaVersion
        self.presets = presets
        self.activePresetID = activePresetID
    }

    public static func makeDefault(postures: [CalibratedPosture] = []) -> PresetLibrary {
        let preset = PosturePreset(name: "기본", postures: postures)
        return PresetLibrary(presets: [preset], activePresetID: preset.id)
    }

    public var activePreset: PosturePreset {
        presets.first { $0.id == activePresetID } ?? presets[0]
    }

    public var activePostures: [CalibratedPosture] {
        activePreset.postures
    }

    public var isCalibrated: Bool {
        activePreset.isCalibrated
    }

    public var canAddPreset: Bool {
        presets.count < Self.maxPresets
    }

    public var canRemovePreset: Bool {
        presets.count > 1
    }

    public func index(of presetID: UUID) -> Int? {
        presets.firstIndex { $0.id == presetID }
    }

    public mutating func update(presetID: UUID, _ transform: (inout PosturePreset) -> Void) {
        guard let index = index(of: presetID) else { return }
        transform(&presets[index])
    }

    public mutating func updateActivePreset(_ transform: (inout PosturePreset) -> Void) {
        update(presetID: activePresetID, transform)
    }

    @discardableResult
    public mutating func addPreset(name: String? = nil, screenSignature: ScreenSignature? = nil) -> UUID? {
        guard canAddPreset else { return nil }
        let preset = PosturePreset(name: name ?? nextPresetName(), screenSignature: screenSignature)
        presets.append(preset)
        activePresetID = preset.id
        return preset.id
    }

    @discardableResult
    public mutating func duplicatePreset(_ presetID: UUID) -> UUID? {
        guard canAddPreset, let source = presets.first(where: { $0.id == presetID }) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.name = uniquePresetName(basedOn: "\(source.name) 사본")
        copy.screenSignature = nil
        copy.postures = source.postures.map { CalibratedPosture(name: $0.name, snapshot: $0.snapshot) }
        presets.append(copy)
        activePresetID = copy.id
        return copy.id
    }

    public mutating func removePreset(_ presetID: UUID) {
        guard canRemovePreset, let index = index(of: presetID) else { return }
        presets.remove(at: index)
        if activePresetID == presetID {
            activePresetID = presets[min(index, presets.count - 1)].id
        }
    }

    public mutating func removePosture(_ postureID: UUID, from presetID: UUID) {
        update(presetID: presetID) { preset in
            preset.postures.removeAll { $0.id == postureID }
        }
    }

    public func preset(matching signature: ScreenSignature) -> PosturePreset? {
        presets.first { $0.screenSignature == signature }
    }

    private func nextPresetName() -> String {
        uniquePresetName(basedOn: "새 프리셋")
    }

    private func uniquePresetName(basedOn base: String) -> String {
        let used = Set(presets.map(\.name))
        guard used.contains(base) else { return base }
        var index = 2
        while used.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
}

public protocol PresetPersisting: Sendable {
    func load() -> PresetLibrary?
    func save(_ library: PresetLibrary) throws
}

public final class PresetStore {
    private let persistence: PresetPersisting
    public private(set) var library: PresetLibrary

    public init(persistence: PresetPersisting) {
        self.persistence = persistence
        self.library = persistence.load() ?? .makeDefault()
    }

    public func replace(with library: PresetLibrary) {
        self.library = library
        try? persistence.save(library)
    }
}

public final class FilePresetPersistence: PresetPersisting, @unchecked Sendable {
    private let fileURL: URL
    private let legacyFileURL: URL?

    public init(fileURL: URL, legacyFileURL: URL? = nil) {
        self.fileURL = fileURL
        self.legacyFileURL = legacyFileURL
    }

    public convenience init(directoryName: String = "Baro") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(
            fileURL: dir.appendingPathComponent("presets.json"),
            legacyFileURL: dir.appendingPathComponent("calibration.json")
        )
    }

    public func load() -> PresetLibrary? {
        if let data = try? Data(contentsOf: fileURL),
           let library = try? JSONDecoder().decode(PresetLibrary.self, from: data),
           !library.presets.isEmpty {
            return library
        }
        return migratedLibrary()
    }

    public func save(_ library: PresetLibrary) throws {
        let data = try JSONEncoder().encode(library)
        try data.write(to: fileURL, options: .atomic)
    }

    private func migratedLibrary() -> PresetLibrary? {
        guard let legacyFileURL,
              let data = try? Data(contentsOf: legacyFileURL),
              let snapshot = try? JSONDecoder().decode(FaceLandmarkSnapshot.self, from: data) else {
            return nil
        }
        let library = PresetLibrary.makeDefault(postures: [CalibratedPosture(name: "기본 자세", snapshot: snapshot)])
        try? save(library)
        try? FileManager.default.removeItem(at: legacyFileURL)
        return library
    }
}

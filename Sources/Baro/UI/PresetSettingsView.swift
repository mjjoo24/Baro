import BaroCore
import SwiftUI

struct PresetSettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var editingPostureID: UUID?

    var body: some View {
        Form {
            Section("프리셋") {
                Picker("사용 중인 프리셋", selection: Binding(
                    get: { appModel.library.activePresetID },
                    set: { appModel.selectPreset($0) }
                )) {
                    ForEach(appModel.library.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }

                TextField("프리셋 이름", text: Binding(
                    get: { appModel.library.activePreset.name },
                    set: { appModel.renamePreset(appModel.library.activePresetID, to: $0) }
                ))
                .id(appModel.library.activePresetID)

                HStack {
                    Button("프리셋 추가") { appModel.addPreset() }
                        .disabled(!appModel.library.canAddPreset)
                    Button("복제") { appModel.duplicateActivePreset() }
                        .disabled(!appModel.library.canAddPreset)
                    Spacer()
                    Button("삭제", role: .destructive) {
                        appModel.removePreset(appModel.library.activePresetID)
                    }
                    .disabled(!appModel.library.canRemovePreset)
                }
            }

            Section {
                ForEach(appModel.library.activePreset.postures) { posture in
                    postureRow(posture)
                        .id(posture.id)
                }

                HStack {
                    Button("자세 추가") { appModel.requestNewPosture(from: .settings) }
                        .disabled(!appModel.library.activePreset.canAddPosture)
                    Spacer()
                    Text("\(appModel.library.activePreset.postures.count) / \(PosturePreset.maxPostures)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                if !appModel.library.activePreset.canAddPosture {
                    Text("자세는 프리셋당 최대 \(PosturePreset.maxPostures)개까지입니다. 많을수록 정상으로 인정되는 범위가 넓어져 감지가 둔해집니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack(spacing: 4) {
                    Text("등록된 자세")
                    InfoButton(title: "자세를 여러 개 두는 이유", text: Self.postureExplanation)
                }
            }

            Section("화면 구성 자동 전환") {
                Toggle("이 화면 구성에서 자동으로 사용", isOn: Binding(
                    get: { appModel.library.activePreset.screenSignature == ScreenConfigurationMonitor.currentSignature() },
                    set: { enabled in
                        if enabled {
                            appModel.bindActivePresetToCurrentScreens()
                        } else {
                            appModel.unbindActivePresetFromScreens()
                        }
                    }
                ))

                Text("지금 연결된 화면: \(appModel.screens.signature.summary) (\(appModel.screens.signature.displaySizes.joined(separator: ", ")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let bound = appModel.library.activePreset.screenSignature,
                   bound != appModel.screens.signature {
                    Text("이 프리셋은 \(bound.summary) 구성에 연결돼 있어요.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("이 프리셋에서만 다르게") {
                Toggle("개별 설정 사용", isOn: Binding(
                    get: { appModel.library.activePreset.overrides != nil },
                    set: { enabled in
                        appModel.updateActiveOverrides(enabled ? PresetOverrides(
                            badScoreThreshold: appModel.settings.badScoreThreshold,
                            warningDuration: appModel.settings.warningDuration,
                            criticalDelayAfterWarning: appModel.settings.criticalDelayAfterWarning,
                            intensity: appModel.settings.intensity
                        ) : nil)
                    }
                ))

                if let overrides = appModel.library.activePreset.overrides {
                    SettingsSliderRow(
                        label: "허용치",
                        value: overrideBinding(\.badScoreThreshold, overrides: overrides, fallback: appModel.settings.badScoreThreshold),
                        range: 20...70, step: 5,
                        valueText: { "\(Int($0)) · \(DetectionSettingsView.sensitivityLabel(for: $0))" }
                    )
                    SettingsSliderRow(
                        label: "경고 지연",
                        value: overrideBinding(\.warningDuration, overrides: overrides, fallback: appModel.settings.warningDuration),
                        range: 1...10, step: 1,
                        valueText: { "\(Int($0))초" }
                    )
                    SettingsSliderRow(
                        label: "개입 지연",
                        value: overrideBinding(\.criticalDelayAfterWarning, overrides: overrides, fallback: appModel.settings.criticalDelayAfterWarning),
                        range: 1...20, step: 1,
                        valueText: { "경고 후 \(Int($0))초" }
                    )
                    Picker("개입 방식", selection: Binding(
                        get: { overrides.intensity ?? appModel.settings.intensity },
                        set: { value in
                            var updated = overrides
                            updated.intensity = value
                            appModel.updateActiveOverrides(updated)
                        }
                    )) {
                        ForEach(InterventionIntensity.allCases, id: \.self) { intensity in
                            Text(intensity.displayName).tag(intensity)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: Binding(
            get: { isSheetPresented },
            set: { presented in
                if !presented {
                    editingPostureID = nil
                    appModel.cancelCalibrationScreen()
                }
            }
        )) {
            sheetContent
                .environmentObject(appModel)
                .frame(width: 320)
                .padding(.vertical, 8)
        }
    }

    private var isSheetPresented: Bool {
        editingPostureID != nil || (appModel.isCalibrationFlowActive && appModel.calibrationPresentation == .settings)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let editingPostureID {
            PostureEditorView(postureID: editingPostureID) {
                self.editingPostureID = nil
            }
        } else {
            OnboardingView()
        }
    }

    private func postureRow(_ posture: CalibratedPosture) -> some View {
        let isMatched = appModel.monitor.matchedPostureID == posture.id
        return HStack(spacing: 8) {
            Image(systemName: isMatched ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isMatched ? Color.accentColor : Color.secondary)
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(posture.name)
                if isMatched {
                    Text("지금 이 자세로 채점 중")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("수정") { editingPostureID = posture.id }
                .buttonStyle(.bordered)
        }
    }

    private func overrideBinding(
        _ keyPath: WritableKeyPath<PresetOverrides, Double?>,
        overrides: PresetOverrides,
        fallback: Double
    ) -> Binding<Double> {
        Binding(
            get: { overrides[keyPath: keyPath] ?? fallback },
            set: { value in
                var updated = overrides
                updated[keyPath: keyPath] = value
                appModel.updateActiveOverrides(updated)
            }
        )
    }

    private static let postureExplanation = """
    모니터가 여러 대면 "바른 자세"가 하나가 아닙니다. 화면마다 한 번씩 자세를 등록해두면, \
    그중 가장 잘 맞는 자세를 기준으로 채점하기 때문에 옆 화면을 볼 때 잘못된 경고가 뜨지 않습니다.

    대신 자세를 등록할수록 정상으로 인정되는 범위가 넓어집니다. 구부정한 자세를 실수로 등록하면 \
    그 자세는 앞으로 계속 정상으로 취급되니, 매번 허리를 펴고 등록해주세요.
    """
}

struct StatsSettingsView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Form {
            Section("오늘") {
                HStack {
                    Text("나쁜 자세 시간 합계")
                    Spacer()
                    Text(Self.formatted(appModel.todayBadPostureSeconds))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Section("자세별") {
                if appModel.library.activePreset.postures.isEmpty {
                    Text("등록된 자세가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.library.activePreset.postures) { posture in
                        let seconds = appModel.badSeconds(for: posture.id)
                        HStack {
                            Text(posture.name)
                            Spacer()
                            if appModel.todayBadPostureSeconds > 0 {
                                ProgressView(value: seconds, total: max(appModel.todayBadPostureSeconds, 1))
                                    .frame(width: 100)
                            }
                            Text(Self.formatted(seconds))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }

                    Text("어떤 자세에서 특히 오래 나빴는지 보여줍니다. 한 자세만 유독 높다면 그 화면의 위치나 각도를 조정해보세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("통계는 앱이 실행 중인 동안만 집계하며, 자정에 초기화됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    static func formatted(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        if minutes > 0 {
            return "\(minutes)분"
        }
        return "\(Int(seconds))초"
    }
}

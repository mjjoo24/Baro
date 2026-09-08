import BaroCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("일반", systemImage: "gearshape") }
            DetectionSettingsView()
                .tabItem { Label("판별", systemImage: "scope") }
            PresetSettingsView()
                .tabItem { Label("프리셋", systemImage: "rectangle.on.rectangle") }
            StatsSettingsView()
                .tabItem { Label("통계", systemImage: "chart.bar") }
        }
        .frame(width: 460)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Form {
            Section("일반") {
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { appModel.settings.launchAtLogin },
                    set: { appModel.setLaunchAtLogin($0) }
                ))
            }

            Section("모니터링") {
                Toggle("카메라 모니터링 사용", isOn: Binding(
                    get: { appModel.settings.cameraEnabled },
                    set: { appModel.toggleCamera($0) }
                ))

                SettingsSliderRow(
                    label: "경고 지연",
                    value: $appModel.settings.warningDuration,
                    range: 1...10, step: 1,
                    valueText: { "\(Int($0))초" }
                )

                SettingsSliderRow(
                    label: "개입 지연",
                    value: $appModel.settings.criticalDelayAfterWarning,
                    range: 1...20, step: 1,
                    valueText: { "경고 후 \(Int($0))초" }
                )

                if appModel.monitor.isCameraBusyElsewhere {
                    Label("다른 앱이 카메라를 사용 중이라 감지가 잠시 멈춰 있어요", systemImage: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Section("개입 방식") {
                Picker("나쁜 자세가 오래 지속되면", selection: $appModel.settings.intensity) {
                    ForEach(InterventionIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.displayName).tag(intensity)
                    }
                }
                .pickerStyle(.radioGroup)

                if appModel.settings.intensity == .turnOffDisplay {
                    Text("⚠️ 화면이 즉시 꺼집니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("프라이버시") {
                Text("모든 영상 분석은 기기 내에서만 처리되며, 네트워크로 전송되거나 저장되지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct DetectionSettingsView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Form {
            Section {
                SettingsSliderRow(
                    label: "허용치",
                    value: $appModel.settings.badScoreThreshold,
                    range: 20...70, step: 5,
                    valueText: { "\(Int($0)) · \(Self.sensitivityLabel(for: $0))" },
                    info: ("자세를 어떻게 판별하나요?", Self.detectionExplanation)
                )
                liveScoreRows
            } header: {
                HStack(spacing: 4) {
                    Text("판별 기준")
                    InfoButton(title: "판별 기준이 뭔가요?", text: Self.breakdownExplanation)
                }
            }

            if appModel.library.activePreset.overrides != nil {
                Section("프리셋 개별 설정") {
                    Text("현재 프리셋 \"\(appModel.library.activePreset.name)\"이(가) 이 값들을 따로 쓰고 있어요. 프리셋 탭에서 확인할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var liveScoreRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 2)
            if appModel.library.activePreset.postures.count > 1 || appModel.monitor.matchedPostureName != nil {
                HStack {
                    Text("기준 자세").font(.caption)
                    Spacer()
                    Text(appModel.monitor.matchedPostureName ?? "–")
                        .font(.caption).bold()
                        .foregroundStyle(.secondary)
                }
            }
            if appModel.monitor.isPostureUnmeasurable {
                Label("고개가 등록된 자세에서 크게 벗어나 판정을 잠시 멈췄어요", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            LiveScoreRow(label: "전방 이동", value: appModel.monitor.scoreBreakdown.forward, isTracking: canShowLiveScore)
            LiveScoreRow(label: "고개 숙임", value: appModel.monitor.scoreBreakdown.downward, isTracking: canShowLiveScore)
            LiveScoreRow(label: "고개 기울임", value: appModel.monitor.scoreBreakdown.tilt, isTracking: canShowLiveScore)
            LiveScoreRow(label: "고개 돌림", value: appModel.monitor.scoreBreakdown.turn, isTracking: canShowLiveScore)
            liveTotalScoreRow
        }
    }

    private var liveTotalScoreRow: some View {
        HStack {
            Text("종합 점수").font(.caption).bold()
            Spacer()
            if canShowLiveScore {
                let total = appModel.monitor.currentScore
                let threshold = appModel.resolvedSettings.badScoreThreshold
                let exceeds = total >= threshold
                Text("\(Int(total)) / \(Int(threshold))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(exceeds ? "임계치 초과" : "정상")
                    .font(.caption2).bold()
                    .foregroundStyle(exceeds ? .red : .green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(exceeds ? Color.red.opacity(0.15) : Color.green.opacity(0.15), in: Capsule())
            } else {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canShowLiveScore: Bool {
        appModel.monitor.isCalibrated && appModel.monitor.isCameraActive && appModel.monitor.isFaceDetected
    }

    static func sensitivityLabel(for value: Double) -> String {
        switch value {
        case ..<35: return "엄격하게"
        case ..<50: return "약간 엄격하게"
        case ..<65: return "보통"
        default: return "느슨하게"
        }
    }

    private static let detectionExplanation = """
    캘리브레이션 때 저장한 "바른 자세" 기준과 지금 얼굴 위치를 비교해 0~100점 점수를 냅니다. \
    머리가 카메라 쪽으로 가까워지거나, 눈 위치가 아래로 내려가거나, 고개를 좌우로 갸웃하거나, 옆으로 돌릴수록 점수가 올라가요.

    프리셋에 자세가 여러 개면 그중 가장 잘 맞는 자세를 기준으로 채점합니다. \
    어느 자세로도 설명이 안 될 만큼 고개가 돌아가 있으면(예: 등록되지 않은 화면을 보는 중) 판정을 잠시 멈춥니다.

    "허용치"는 점수 자체를 바꾸는 게 아니라, 그 점수를 얼마나 봐줄지(문턱값)를 정해요. \
    허용치를 낮추면 조금만 나빠져도 반응하고(엄격), 높이면 확실히 나빠야 반응합니다(느슨).
    """

    private static let breakdownExplanation = """
    네 지표는 서로 독립적으로 각각 0~100점까지 계산됩니다. \
    한 가지만 심하게 나빠도(예: 화면에 바짝 붙음) 그 지표 혼자 100점에 도달할 수 있어요.

    "고개 기울임"은 고개를 좌우로 갸웃하는 것, "고개 돌림"은 고개를 옆으로 돌리는 것으로 서로 다른 값입니다.

    종합 점수는 이 네 값을 그냥 더한 값이며(최대 100으로 제한), 위 "허용치"와 비교해 경고/개입 여부를 정합니다.
    """
}

struct LiveScoreRow: View {
    let label: String
    let value: Double
    let isTracking: Bool

    var body: some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            if isTracking {
                ProgressView(value: value, total: 100)
                    .frame(width: 100)
                Text("\(Int(value))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            } else {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String
    var info: (title: String, text: String)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                if let info {
                    InfoButton(title: info.title, text: info.text)
                }
                Spacer()
                Text(valueText(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct InfoButton: View {
    let title: String
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 320)
        }
    }
}

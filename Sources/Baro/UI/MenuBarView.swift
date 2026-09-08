import BaroCore
import SwiftUI

private let menuRowHeight: CGFloat = 28

struct MenuBarView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var isSnoozeMenuPresented = false
    @State private var isPresetMenuPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !appModel.monitor.isCalibrated
                || (appModel.isCalibrationFlowActive && appModel.calibrationPresentation == .menuBar) {
                OnboardingView()
                    .padding(16)
            } else {
                heroCard
                statsRow
                Divider().padding(.horizontal, 12)
                actionsSection
                    .padding(.vertical, 6)
            }
        }
        .frame(width: 300)
    }

    private var heroCard: some View {
        HStack(spacing: 12) {
            PostureGlyph(state: appModel.monitor.state, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(appModel.monitor.state.headline)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(appModel.monitor.state.tintColor.opacity(0.12))
    }

    private var statusLine: String {
        if !appModel.monitor.isCameraActive {
            return "모니터링이 꺼져 있어요"
        }
        if appModel.monitor.isPostureUnmeasurable {
            return "등록되지 않은 방향을 보고 있어 판정을 멈췄어요"
        }
        if let posture = appModel.monitor.matchedPostureName,
           appModel.library.activePreset.postures.count > 1 {
            return "기준 자세: \(posture)"
        }
        return "카메라로 확인하고 있어요"
    }

    private var statsRow: some View {
        HStack {
            Text("오늘 나쁜 자세 시간")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formattedDuration(appModel.todayBadPostureSeconds))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let switched = appModel.autoSwitchedPresetName {
                MenuRow(icon: "rectangle.on.rectangle.angled", label: "\(switched) 프리셋으로 전환됨", tint: .blue) {
                    appModel.dismissAutoSwitchNotice()
                }
            } else if appModel.monitor.isCameraBusyElsewhere {
                statusNote("화상통화 중으로 보여 감지를 잠시 멈췄어요", icon: "video.fill", tint: .blue)
            } else if appModel.intervention.isSnoozed {
                MenuRow(icon: "bell.fill", label: "감지 다시 켜기") {
                    appModel.cancelSnooze()
                }
            } else {
                snoozeRow
            }

            presetRow

            MenuRow(icon: "plus.viewfinder", label: "자세 추가") {
                appModel.requestNewPosture()
            }

            MenuRow(icon: "gearshape", label: "설정 열기") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }

            Divider().padding(.horizontal, 8).padding(.vertical, 4)

            MenuRow(icon: "power", label: "종료", tint: .secondary) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var snoozeRow: some View {
        MenuRow(icon: "bell.slash", label: "잠시 끄기", trailing: "chevron.down") {
            isSnoozeMenuPresented = true
        }
        .popover(isPresented: $isSnoozeMenuPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach([5, 10, 15, 30, 60, 120], id: \.self) { minutes in
                    MenuRow(icon: "clock", label: snoozeLabel(for: minutes)) {
                        isSnoozeMenuPresented = false
                        appModel.snooze(minutes: minutes)
                    }
                }
            }
            .padding(6)
            .frame(width: 170)
        }
    }

    private var presetRow: some View {
        MenuRow(icon: "rectangle.on.rectangle", label: appModel.library.activePreset.name, trailing: "chevron.down") {
            isPresetMenuPresented = true
        }
        .popover(isPresented: $isPresetMenuPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(appModel.library.presets) { preset in
                    MenuRow(
                        icon: preset.id == appModel.library.activePresetID ? "checkmark" : "rectangle.on.rectangle",
                        label: preset.name
                    ) {
                        isPresetMenuPresented = false
                        appModel.selectPreset(preset.id)
                    }
                }
            }
            .padding(6)
            .frame(width: 200)
        }
    }

    private func snoozeLabel(for minutes: Int) -> String {
        minutes < 60 ? "\(minutes)분 동안" : "\(minutes / 60)시간 동안"
    }

    private func statusNote(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }
}

private struct MenuRow: View {
    let icon: String
    let label: String
    var tint: Color = .primary
    var trailing: String? = nil
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(label)
                Spacer(minLength: 0)
                if let trailing {
                    Image(systemName: trailing)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: menuRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        .onHover { isHovering = $0 }
    }
}

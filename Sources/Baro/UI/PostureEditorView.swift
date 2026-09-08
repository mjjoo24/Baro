import BaroCore
import SwiftUI

struct PostureEditorView: View {
    @EnvironmentObject var appModel: AppModel
    let postureID: UUID
    let onClose: () -> Void

    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        Group {
            if appModel.isCalibrationFlowActive && appModel.calibrationPresentation == .settings {
                OnboardingView()
            } else if let posture = appModel.library.activePreset.posture(with: postureID) {
                editor(posture)
            } else {
                missingPostureView
            }
        }
        .frame(width: 280)
        .padding(20)
    }

    private func editor(_ posture: CalibratedPosture) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("자세 수정")
                .font(.headline)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text("이름")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("자세 이름", text: Binding(
                    get: { appModel.library.activePreset.posture(with: postureID)?.name ?? posture.name },
                    set: { appModel.renamePosture(postureID, to: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .id(postureID)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("기준 자세")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(capturedDescription(posture))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("다시 측정") {
                        appModel.requestRecalibration(postureID: postureID, from: .settings)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            HStack {
                Button("삭제", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("완료") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .confirmationDialog(
            "\"\(posture.name)\" 자세를 삭제할까요?",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("삭제", role: .destructive) {
                appModel.removePosture(postureID)
                onClose()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 이 자세는 더 이상 정상으로 인정되지 않습니다.")
        }
    }

    private var missingPostureView: some View {
        VStack(spacing: 12) {
            Text("자세를 찾을 수 없어요")
                .font(.headline)
            Button("닫기") { onClose() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func capturedDescription(_ posture: CalibratedPosture) -> String {
        guard let capturedAt = posture.capturedAt else { return "측정 시각 기록 없음" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm 측정"
        return formatter.string(from: capturedAt)
    }
}

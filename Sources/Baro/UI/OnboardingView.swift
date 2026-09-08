import AppKit
import SwiftUI
import BaroCore

struct OnboardingView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Text(headline)
                .font(.headline)

            if appModel.monitor.isCameraPermissionDenied {
                permissionDeniedView
            } else if !appModel.monitor.isCameraActive {
                primingView
            } else if let pending = appModel.pendingRegistration {
                registrationWarningView(pending)
            } else {
                previewAndCalibrationView
            }

            Text("카메라 영상은 기기 밖으로 전송되지 않으며, 분석 후 즉시 폐기됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(width: 280)
    }

    private var primingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)

            Text("자세를 감지하려면 카메라로 얼굴 위치를 봐야 해요.\n버튼을 누르면 macOS가 카메라 접근을 허락할지 물어봅니다.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("카메라 켜기") {
                appModel.primeCamera()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var previewAndCalibrationView: some View {
        VStack(spacing: 12) {
            previewThumbnail
            faceDetectionBadge

            if appModel.monitor.isCalibrating {
                ProgressView(value: appModel.monitor.calibrationProgress)
                    .frame(width: 200)
                Text("측정 중에는 움직이지 말아주세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if let reason = appModel.monitor.calibrationAbortReason {
                    Text(abortMessage(for: reason))
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.orange)
                } else {
                    Text("허리를 펴고 평소 작업하는 바른 자세로 화면을 바라봐 주세요.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    if appModel.monitor.isCalibrated {
                        Button("취소") {
                            appModel.cancelCalibrationScreen()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button(appModel.monitor.calibrationAbortReason == nil ? "캘리브레이션 시작" : "다시 시작") {
                        appModel.beginCalibration()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!appModel.monitor.isFaceDetected)
                }
            }
        }
    }

    private var headline: String {
        if appModel.pendingRegistration != nil {
            return "이대로 등록할까요?"
        }
        if appModel.library.activePreset.isCalibrated {
            return "자세를 측정할게요"
        }
        return "자세 기준을 설정해주세요"
    }

    private func registrationWarningView(_ pending: PendingPostureRegistration) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text(warningMessage(for: pending.warning))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("다시 측정") {
                    appModel.discardPendingRegistration()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("그대로 등록") {
                    appModel.confirmPendingRegistration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func warningMessage(for warning: PostureRegistrationWarning) -> String {
        switch warning {
        case .duplicate(let existingName):
            return "이미 등록된 \"\(existingName)\"과(와) 거의 같은 자세예요.\n등록해도 판정이 달라지지 않습니다."
        case .worseThanRegistered(let existingName, let score):
            return "\"\(existingName)\"보다 자세가 나빠 보여요 (\(Int(score))점).\n이대로 등록하면 이 자세는 앞으로 정상으로 봅니다."
        }
    }

    private func abortMessage(for reason: CalibrationAbortReason) -> String {
        switch reason {
        case .moved:
            return "측정 중에 자세가 바뀌어서 취소했어요.\n자세를 잡은 뒤 다시 시작해주세요."
        case .faceLost:
            return "측정 중에 얼굴이 화면에서 벗어나 취소했어요.\n카메라를 보고 다시 시작해주세요."
        }
    }

    private var previewThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))

            if let previewImage = appModel.monitor.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: 200, height: 150)
    }

    private var faceDetectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(appModel.monitor.isFaceDetected ? .green : .red)
                .frame(width: 7, height: 7)
            Text(appModel.monitor.isFaceDetected ? "얼굴 인식됨" : "얼굴 인식 안 됨")
                .font(.caption2).bold()
                .foregroundStyle(.secondary)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 8) {
            Label("카메라 접근 권한이 꺼져 있어요", systemImage: "exclamationmark.triangle.fill")
                .font(.callout).bold()
                .foregroundStyle(.orange)
            Text("시스템 설정 > 개인정보 보호 및 보안 > 카메라에서 Baro를 켜주세요.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("시스템 설정 열기") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

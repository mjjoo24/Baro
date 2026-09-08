import AppKit
import SwiftUI
import BaroCore

public final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private let content = OverlayContentState()

    public var onDismissRequested: (() -> Void)? {
        get { content.onDismissRequested }
        set { content.onDismissRequested = newValue }
    }

    public init() {}

    public var isVisible: Bool { !windows.isEmpty }

    public func show(style: OverlayStyle) {
        content.style = style

        guard windows.isEmpty else {
            content.opacity = 1
            return
        }

        content.opacity = 0
        windows = NSScreen.screens.map { screen in
            makeWindow(for: screen)
        }
        windows.forEach { $0.orderFrontRegardless() }
        content.opacity = 1
    }

    public func updateStyle(_ style: OverlayStyle) {
        content.style = style
    }

    public func updateLiveScore(
        breakdown: PostureScoreBreakdown,
        threshold: Double,
        postureName: String?,
        isTracking: Bool
    ) {
        content.breakdown = breakdown
        content.threshold = threshold
        content.postureName = postureName
        content.isTracking = isTracking
    }

    public func hide() {
        guard !windows.isEmpty else { return }
        content.opacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.windows.forEach { $0.orderOut(nil) }
            self?.windows.removeAll()
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: OverlayContentView(state: content))
        return window
    }
}

public enum OverlayStyle: Sendable {
    case dim
    case blur
}

final class OverlayContentState: ObservableObject {
    @Published var style: OverlayStyle = .dim
    @Published var opacity: Double = 0
    @Published var breakdown: PostureScoreBreakdown = .zero
    @Published var threshold: Double = 45
    @Published var postureName: String?
    @Published var isTracking: Bool = false
    var onDismissRequested: (() -> Void)?
}

private struct OverlayContentView: View {
    @ObservedObject var state: OverlayContentState

    var body: some View {
        ZStack {
            switch state.style {
            case .dim:
                Color.black.opacity(0.75)
            case .blur:
                VisualEffectBlur()
            }

            VStack(spacing: 16) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 40))
                Text("자세가 흐트러졌어요")
                    .font(.title2).bold()
                Text("허리를 펴고 자세를 바로 하면 화면이 원래대로 돌아옵니다")
                    .font(.body)
                    .opacity(0.8)

                liveScoreCard
                    .padding(.top, 4)

                Button("지금은 아니에요 (5분 미루기)") {
                    state.onDismissRequested?()
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.top, 8)
            }
            .foregroundColor(.white)
            .padding(32)
        }
        .opacity(state.opacity)
        .animation(.easeInOut(duration: 0.6), value: state.opacity)
        .ignoresSafeArea()
    }

    private var liveScoreCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let postureName = state.postureName {
                HStack {
                    Text("기준 자세")
                        .font(.caption)
                    Spacer()
                    Text(postureName)
                        .font(.caption).bold()
                }
                Divider().overlay(Color.white.opacity(0.25))
            }
            scoreRow("전방 이동", value: state.breakdown.forward)
            scoreRow("고개 숙임", value: state.breakdown.downward)
            scoreRow("고개 기울임", value: state.breakdown.tilt)
            scoreRow("고개 돌림", value: state.breakdown.turn)
            Divider().overlay(Color.white.opacity(0.25))
            totalScoreRow
        }
        .frame(width: 260)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var totalScoreRow: some View {
        HStack {
            Text("종합 점수").font(.caption).bold()
            Spacer()
            if state.isTracking {
                let exceeds = state.breakdown.total >= state.threshold
                Text("\(Int(state.breakdown.total)) / \(Int(state.threshold))")
                    .font(.caption)
                    .monospacedDigit()
                    .opacity(0.8)
                Text(exceeds ? "임계치 초과" : "정상")
                    .font(.caption2).bold()
                    .foregroundStyle(exceeds ? Color.red : Color.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (exceeds ? Color.red : Color.green).opacity(0.2),
                        in: Capsule()
                    )
            } else {
                Text("–")
                    .font(.caption)
                    .opacity(0.6)
            }
        }
    }

    private func scoreRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            if state.isTracking {
                ProgressView(value: value, total: 100)
                    .tint(.white)
                    .frame(width: 100)
                Text("\(Int(value))")
                    .font(.caption)
                    .monospacedDigit()
                    .opacity(0.8)
                    .frame(width: 24, alignment: .trailing)
            } else {
                Text("–")
                    .font(.caption)
                    .opacity(0.6)
            }
        }
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .fullScreenUI
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

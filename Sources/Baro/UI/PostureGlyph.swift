import SwiftUI
import BaroCore

extension PostureState {
    var tintColor: Color {
        switch self {
        case .good: return Color(red: 0.16, green: 0.62, blue: 0.47)
        case .warning: return Color(red: 0.89, green: 0.64, blue: 0.24)
        case .critical: return Color(red: 0.88, green: 0.35, blue: 0.30)
        }
    }

    var headline: String {
        switch self {
        case .good: return "좋은 자세예요"
        case .warning: return "자세를 확인해주세요"
        case .critical: return "나쁜 자세가 계속되고 있어요"
        }
    }
}

struct PostureGlyph: View {
    let state: PostureState
    var size: CGFloat = 40

    private var lean: CGFloat {
        switch state {
        case .good: return 0
        case .warning: return size * 0.16
        case .critical: return size * 0.30
        }
    }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let headRadius = w * 0.17
            let baseX = w * 0.5
            let headCenter = CGPoint(x: baseX + lean, y: headRadius + h * 0.04)

            var spine = Path()
            spine.move(to: CGPoint(x: baseX, y: h * 0.94))
            spine.addQuadCurve(
                to: CGPoint(x: headCenter.x, y: headCenter.y + headRadius * 0.85),
                control: CGPoint(x: baseX + lean * 0.55, y: h * 0.42)
            )

            context.stroke(spine, with: .color(state.tintColor), style: StrokeStyle(lineWidth: max(2.5, w * 0.09), lineCap: .round))

            let headRect = CGRect(x: headCenter.x - headRadius, y: headCenter.y - headRadius, width: headRadius * 2, height: headRadius * 2)
            context.fill(Path(ellipseIn: headRect), with: .color(state.tintColor))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

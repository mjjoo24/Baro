import Foundation

public enum InterventionIntensity: String, CaseIterable, Codable, Sendable, Hashable {
    case menuBarOnly = "notifyOnly"
    case dim
    case blur
    case turnOffDisplay

    public var displayName: String {
        switch self {
        case .menuBarOnly: return "메뉴바에만 표시"
        case .dim: return "화면 어둡게"
        case .blur: return "화면 흐리게"
        case .turnOffDisplay: return "화면 끄기"
        }
    }
}

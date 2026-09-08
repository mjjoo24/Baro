import AppKit
import Combine
import Foundation
import BaroCore

@MainActor
public final class ScreenConfigurationMonitor: ObservableObject {
    @Published public private(set) var signature: ScreenSignature

    public var onChange: ((ScreenSignature) -> Void)?

    private var observer: NSObjectProtocol?

    public init() {
        signature = Self.currentSignature()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public static func currentSignature() -> ScreenSignature {
        let sizes = NSScreen.screens.map { screen -> String in
            let frame = screen.frame
            return "\(Int(frame.width))x\(Int(frame.height))"
        }
        return ScreenSignature(displaySizes: sizes)
    }

    private func refresh() {
        let updated = Self.currentSignature()
        guard updated != signature else { return }
        signature = updated
        onChange?(updated)
    }
}

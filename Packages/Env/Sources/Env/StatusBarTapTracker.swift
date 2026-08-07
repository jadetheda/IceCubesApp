import SwiftUI
import UIKit

public extension Notification.Name {
    static let statusBarTapped = Notification.Name("statusBarTapped")
}

public class StatusBarWindow: UIWindow {
    private var lastTapTime: TimeInterval = 0

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Ensure we are tapping within the status bar region (top 50 points)
        let statusBarHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 50
            
        if point.y >= 0 && point.y <= statusBarHeight {
            let now = Date().timeIntervalSince1970
            // Debounce to prevent multiple hits from the same touch cycle (UIKit calls hitTest multiple times per touch)
            if now - lastTapTime > 0.5 {
                lastTapTime = now
                NotificationCenter.default.post(name: .statusBarTapped, object: nil)
            }
        }
        return nil
    }
}

@MainActor
public class StatusBarTapTracker: ObservableObject {
    public static let shared = StatusBarTapTracker()
    
    private var window: StatusBarWindow?
    
    public func setup() {
        guard window == nil else { return }
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            let window = StatusBarWindow(windowScene: windowScene)
            window.frame = windowScene.coordinateSpace.bounds
            window.windowLevel = .statusBar + 1
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = true
            window.isHidden = false
            self.window = window
        }
    }
}

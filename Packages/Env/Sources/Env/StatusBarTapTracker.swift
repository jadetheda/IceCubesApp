import SwiftUI
import UIKit

public extension Notification.Name {
    static let statusBarTapped = Notification.Name("statusBarTapped")
}

public class StatusBarWindow: UIWindow {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if point.y <= 50 {
            NotificationCenter.default.post(name: .statusBarTapped, object: nil)
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

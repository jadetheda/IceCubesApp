import SwiftUI
import Models

public struct StatusVisibilityModifier: ViewModifier {
  let status: Status
  let fetcher: any StatusesFetcher
  let requiresMediaToLoad: Bool

  @State private var isVisible: Bool = false

  public func body(content: Content) -> some View {
    Group {
      if #available(iOS 18.0, visionOS 2.0, macOS 15.0, *) {
        content
          .onScrollVisibilityChange(threshold: 0.5) { visible in
            isVisible = visible
            handleVisibilityChange(visible: visible)
          }
      } else {
        content
          .onAppear {
            isVisible = true
            handleVisibilityChange(visible: true)
          }
          .onDisappear {
            isVisible = false
            handleVisibilityChange(visible: false)
          }
      }
    }
    .environment(\.statusOnMediaLoaded) {
      if isVisible {
        fetcher.statusDidAppear(status: status)
      }
    }
  }

  private func handleVisibilityChange(visible: Bool) {
    if visible {
      if requiresMediaToLoad {
        if status.mediaAttachments.isEmpty {
          fetcher.statusDidAppear(status: status)
        }
      } else {
        fetcher.statusDidAppear(status: status)
      }
    } else {
      fetcher.statusDidDisappear(status: status)
    }
  }
}

extension View {
  public func trackStatusVisibility(
    status: Status, 
    fetcher: any StatusesFetcher, 
    requiresMediaToLoad: Bool = false
  ) -> some View {
    modifier(StatusVisibilityModifier(status: status, fetcher: fetcher, requiresMediaToLoad: requiresMediaToLoad))
  }
}

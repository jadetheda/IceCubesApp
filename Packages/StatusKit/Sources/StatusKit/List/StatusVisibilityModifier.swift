import SwiftUI
import Models
import Env

@MainActor
public struct StatusVisibilityModifier<Fetcher: StatusesFetcher>: ViewModifier {
  public let status: Status
  public let fetcher: Fetcher
  public let requiresMediaToLoad: Bool

  public init(status: Status, fetcher: Fetcher, requiresMediaToLoad: Bool) {
    self.status = status
    self.fetcher = fetcher
    self.requiresMediaToLoad = requiresMediaToLoad
  }

  public func body(content: Content) -> some View {
    content
      .onScrollVisibilityChange(threshold: 0.1) { isVisible in
        if isVisible {
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
      .environment(\.statusOnMediaLoaded) {
        if requiresMediaToLoad {
          fetcher.statusDidAppear(status: status)
        }
      }
  }
}

public extension View {
  @MainActor
  func trackStatusVisibility<Fetcher: StatusesFetcher>(
    status: Status,
    fetcher: Fetcher,
    requiresMediaToLoad: Bool
  ) -> some View {
    modifier(StatusVisibilityModifier(
      status: status,
      fetcher: fetcher,
      requiresMediaToLoad: requiresMediaToLoad
    ))
  }
}

import SwiftUI
import Models
import Env

@MainActor
public struct StatusVisibilityModifier: ViewModifier {
  let status: Status
  let fetcher: any StatusesFetcher
  let rowViewModel: StatusRowViewModel?
  let requiresMediaToLoad: Bool

  @State private var isVisible: Bool = false

  public init(
    status: Status,
    fetcher: any StatusesFetcher,
    rowViewModel: StatusRowViewModel? = nil,
    requiresMediaToLoad: Bool = false
  ) {
    self.status = status
    self.fetcher = fetcher
    self.rowViewModel = rowViewModel
    self.requiresMediaToLoad = requiresMediaToLoad
  }

  private var isHiddenByFilter: Bool {
    if let rowViewModel {
      if rowViewModel.isFiltered {
        return true
      }
    }
    if status.isHidden {
      return true
    }
    if let reblog = status.reblog {
      if reblog.isHidden {
        return true
      }
    }
    if let filtered = status.filtered {
      if filtered.contains(where: { $0.filter.filterAction == .hide }) {
        return true
      }
    }
    if let reblogFiltered = status.reblog?.filtered {
      if reblogFiltered.contains(where: { $0.filter.filterAction == .hide }) {
        return true
      }
    }
    return false
  }

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
        if !isHiddenByFilter {
          fetcher.statusDidAppear(status: status)
        }
      }
    }
    .onChange(of: rowViewModel?.isFiltered) { _, isFiltered in
      if isVisible {
        if isFiltered == false {
          handleVisibilityChange(visible: true)
        } else {
          fetcher.statusDidDisappear(status: status)
        }
      }
    }
  }

  private func handleVisibilityChange(visible: Bool) {
    if visible {
      if isHiddenByFilter {
        return
      }
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

public extension View {
  @MainActor
  func trackStatusVisibility(
    status: Status, 
    fetcher: any StatusesFetcher, 
    rowViewModel: StatusRowViewModel? = nil,
    requiresMediaToLoad: Bool = false
  ) -> some View {
    modifier(StatusVisibilityModifier(
      status: status,
      fetcher: fetcher,
      rowViewModel: rowViewModel,
      requiresMediaToLoad: requiresMediaToLoad
    ))
  }
}

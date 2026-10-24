import Foundation
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
  @AppStorage("timeline_hidden_languages") private var hiddenLanguages: [String] = []

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

  private var isHiddenByLanguage: Bool {
    guard !hiddenLanguages.isEmpty else { return false }
    if let lang = status.language ?? status.reblog?.language {
      if hiddenLanguages.contains(lang) {
        return true
      }
    }
    if hiddenLanguages.contains("ja") || hiddenLanguages.contains("zh") {
      let isTextOnly = status.mediaAttachments.isEmpty && (status.reblog?.mediaAttachments.isEmpty ?? true)
      if isTextOnly {
        let text = status.reblog?.content.asRawText ?? status.content.asRawText
        if hiddenLanguages.contains("ja") {
          if text.range(of: "[\\u3040-\\u309F\\u30A0-\\u30FF]", options: .regularExpression) != nil {
            return true
          }
        }
        if hiddenLanguages.contains("zh") {
          if text.range(of: "[\\u4E00-\\u9FFF]", options: .regularExpression) != nil {
            return true
          }
        }
      }
    }
    return false
  }

  private var isHiddenByFilter: Bool {
    if isHiddenByLanguage {
      return true
    }
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
    .onChange(of: hiddenLanguages) { _, _ in
      if isVisible {
        if isHiddenByFilter {
          fetcher.statusDidDisappear(status: status)
        } else {
          handleVisibilityChange(visible: true)
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

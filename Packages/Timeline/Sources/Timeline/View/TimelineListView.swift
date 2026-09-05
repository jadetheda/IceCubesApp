import Charts
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftData
import SwiftUI

@MainActor
struct TimelineListView: View {
  @Environment(\.selectedTabScrollToTop) private var selectedTabScrollToTop
  @Environment(\.currentTabId) private var currentTabId

  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath
  @Environment(Theme.self) private var theme

  var viewModel: TimelineViewModel
  @Binding var timeline: TimelineFilter
  @Binding var pinnedFilters: [TimelineFilter]
  @Binding var selectedTagGroup: TagGroup?
  @Binding var scrollToIdAnimated: String?

  var body: some View {
    @Bindable var viewModel = viewModel
    ScrollViewReader { proxy in
      List {
        ScrollToView()
          .frame(height: pinnedFilters.isEmpty ? .layoutPadding : 0.5)
          .onAppear {
            viewModel.scrollToTopVisible = true
          }
          .onDisappear {
            viewModel.scrollToTopVisible = false
          }
        
        TimelineTagGroupheaderView(group: $selectedTagGroup, timeline: $timeline)
        TimelineTagHeaderView(tag: $viewModel.tag)
        
        switch viewModel.timeline {
        case .remoteLocal:
          StatusesListView(
            fetcher: viewModel,
            client: client,
            routerPath: routerPath,
            isRemote: true,
            filterContext: timeline.filterContext)
        default:
          StatusesListView(
            fetcher: viewModel,
            client: client,
            routerPath: routerPath,
            filterContext: timeline.filterContext)
            .environment(\.isHomeTimeline, timeline == .home)
        }
      }
      .id(client.id)
      .environment(\.defaultMinListRowHeight, 1)
      .listStyle(.plain)
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.primaryBackgroundColor.ignoresSafeArea())
      #endif
      .onChange(of: TimelineContentFilter.shared.isGalleryMode) { oldValue, newValue in
        if oldValue != newValue {
          let targetId = viewModel.getTopVisibleStatusId()
          if let targetId = targetId {
            Task {
              try? await Task.sleep(nanoseconds: 300_000_000)
              await MainActor.run {
                proxy.scrollTo(targetId, anchor: .top)
              }
            }
          }
        }
      }
      .onChange(of: viewModel.scrollToId) { _, newValue in
        if let newValue {
          proxy.scrollTo(newValue, anchor: .top)
          viewModel.scrollToId = nil
        }
      }
      .onChange(of: scrollToIdAnimated) { _, newValue in
        if let newValue {
          withAnimation {
            proxy.scrollTo(newValue, anchor: .top)
            scrollToIdAnimated = nil
          }
        }
      }
      .onChange(of: selectedTabScrollToTop) { _, newValue in
        if let currentTabId, newValue == currentTabId, routerPath.path.isEmpty {
          if let previous = viewModel.handleScrollToTopTrigger() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              scrollToIdAnimated = previous
            }
          } else {
            withAnimation {
              proxy.scrollTo(ScrollToView.Constants.scrollToTop, anchor: .top)
            }
          }
        }
      }
    }
  }
}

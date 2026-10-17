import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

@MainActor
public struct StatusesListView<Fetcher>: View where Fetcher: StatusesFetcher {
  @Environment(Theme.self) private var theme

  @State private var fetcher: Fetcher
  // Whether this status is on a remote local timeline (many actions are unavailable if so)
  private let isRemote: Bool
  private let routerPath: RouterPath
  private let client: FediverseClient
  private let filterContext: Filter.Context?

  public init(
    fetcher: Fetcher,
    client: FediverseClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    filterContext: Filter.Context? = nil
  ) {
    _fetcher = .init(initialValue: fetcher)
    self.isRemote = isRemote
    self.client = client
    self.routerPath = routerPath
    self.filterContext = filterContext
  }

  public var body: some View {
    switch fetcher.statusesState {
    case .loading:
      ForEach(Status.placeholders()) { status in
        StatusRowView(
          viewModel: .init(
            status: status,
            client: client,
            routerPath: routerPath,
            filterContext: filterContext),
          context: .timeline
        )
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
      }
    case .error:
      ErrorView(
        title: "status.error.title",
        message: "status.error.loading.message",
        buttonTitle: "action.retry"
      ) {
        await fetcher.fetchNewestStatuses(pullToRefresh: false)
      }
      .listRowBackground(theme.primaryBackgroundColor)
      .listRowSeparator(.hidden)

    case .display(let statuses, let nextPageState):
      ForEach(statuses) { status in
        StatusRowContainer(
          status: status,
          client: client,
          routerPath: routerPath,
          isRemote: isRemote,
          filterContext: filterContext,
          fetcher: fetcher
        )
      }
      makeNextPageRow(nextPageState: nextPageState)

    case .displayWithGaps(let items, let nextPageState):
      ForEach(items) { item in
        ZStack {
          switch item {
          case .status(let status):
            StatusRowContainer(
              status: status,
              client: client,
              routerPath: routerPath,
              isRemote: isRemote,
              filterContext: filterContext,
              fetcher: fetcher
            )

          case .gap(let gap):
            ZStack {
              if let gapLoader = fetcher as? GapLoadingFetcher {
                TimelineGapView(gap: gap) {
                  await gapLoader.loadGap(gap: gap)
                }
              }
            }
          }
        }
        #if os(visionOS)
          .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
              .foregroundStyle(.background).hoverEffect()
          )
          .listRowHoverEffectDisabled()
        #else
          .listRowBackground(makeBackgroundColorFor(status: item.status))
        #endif
        .listRowInsets(
          .init(
            top: 0,
            leading: .layoutPadding,
            bottom: 0,
            trailing: .layoutPadding)
        )
        .alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
          return -100
        }
        .alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
          return viewDimensions.width + 100
        }
      }
      makeNextPageRow(nextPageState: nextPageState)
    }
  }

  @ViewBuilder
  private func makeNextPageRow(nextPageState: StatusesState.PagingState) -> some View {
    ZStack {
      switch nextPageState {
      case .hasNextPage:
        NextPageView {
          try await fetcher.fetchNextPage()
        }
        .padding(.horizontal, .layoutPadding)

      case .none:
        EmptyView()
      }
    }
    .listRowSeparator(.hidden, edges: .all)
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
    .alignmentGuide(.listRowSeparatorLeading) { _ in
      -100
    }
  }

  private func makeBackgroundColorFor(status: Status?) -> Color {
    if let status {
      if status.visibility == .direct {
        return theme.tintColor.opacity(0.15)
      } else if status.mentions.first(where: { $0.id == CurrentAccount.shared.account?.id }) != nil
      {
        return theme.secondaryBackgroundColor
      } else {
        return theme.primaryBackgroundColor
      }
    } else {
      return theme.primaryBackgroundColor
    }
  }
}

@MainActor
private struct StatusRowContainer: View {
  let status: Status
  let client: FediverseClient
  let routerPath: RouterPath
  let isRemote: Bool
  let filterContext: Filter.Context?
  let fetcher: any StatusesFetcher

  @State private var viewModel: StatusRowViewModel

  init(
    status: Status,
    client: FediverseClient,
    routerPath: RouterPath,
    isRemote: Bool,
    filterContext: Filter.Context?,
    fetcher: any StatusesFetcher
  ) {
    self.status = status
    self.client = client
    self.routerPath = routerPath
    self.isRemote = isRemote
    self.filterContext = filterContext
    self.fetcher = fetcher
    _viewModel = State(initialValue: StatusRowViewModel(
      status: status,
      client: client,
      routerPath: routerPath,
      isRemote: isRemote,
      filterContext: filterContext
    ))
  }

  var body: some View {
    StatusRowView(viewModel: viewModel, context: .timeline)
      .trackStatusVisibility(
        status: status,
        fetcher: fetcher,
        rowViewModel: viewModel,
        requiresMediaToLoad: true
      )
  }
}


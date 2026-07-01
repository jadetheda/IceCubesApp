import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI
import MediaUI
import NukeUI

@MainActor
public struct GalleryStatusesListView<Fetcher>: View where Fetcher: StatusesFetcher {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath

  @State private var fetcher: Fetcher
  private let isRemote: Bool
  private let client: MastodonClient
  private let filterContext: Filter.Context?

  public init(
    fetcher: Fetcher,
    client: MastodonClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    filterContext: Filter.Context? = nil
  ) {
    _fetcher = .init(initialValue: fetcher)
    self.isRemote = isRemote
    self.client = client
    self.filterContext = filterContext
  }

  public var body: some View {
    switch fetcher.statusesState {
    case .loading:
      ProgressView()
        .listRowBackground(theme.primaryBackgroundColor)
    case .error:
      ErrorView(
        title: "status.error.title",
        message: "status.error.loading.message",
        buttonTitle: "action.retry"
      ) {
        await fetcher.fetchNewestStatuses(pullToRefresh: false)
      }
      .listRowBackground(theme.primaryBackgroundColor)
    case .display(let statuses, let nextPageState):
      makeGrid(for: statuses)
      makeNextPageRow(nextPageState: nextPageState)
    case .displayWithGaps(let items, let nextPageState):
      let statuses = items.compactMap { item -> Status? in
          if case let .status(status) = item { return status }
          return nil
      }
      makeGrid(for: statuses)
      makeNextPageRow(nextPageState: nextPageState)
    }
  }

  @ViewBuilder
  private func makeNextPageRow(nextPageState: StatusesState.PagingState) -> some View {
    if nextPageState == .hasNextPage {
      HStack {
        Spacer()
        ProgressView()
        Spacer()
      }
      .padding()
      .onAppear {
        Task { try? await fetcher.fetchNextPage() }
      }
      .listRowBackground(theme.primaryBackgroundColor)
    }
  }

  @ViewBuilder
  private func makeGrid(for statuses: [Status]) -> some View {
    let mediaStatuses = statuses.flatMap { $0.asMediaStatus }
    let chunks = mediaStatuses.chunked(into: 3)
    ForEach(0..<chunks.count, id: \.self) { rowIndex in
      HStack(spacing: 4) {
        ForEach(chunks[rowIndex]) { status in
          GalleryMediaCell(mediaStatus: status, routerPath: routerPath)
            .onAppear { fetcher.statusDidAppear(status: status.status) }
            .onDisappear { fetcher.statusDidDisappear(status: status.status) }
        }
        // Fill empty spaces in the last row
        if chunks[rowIndex].count < 3 {
          ForEach(0..<(3 - chunks[rowIndex].count), id: \.self) { _ in
            Color.clear.aspectRatio(1, contentMode: .fit)
          }
        }
      }
      .listRowBackground(theme.primaryBackgroundColor)
      .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
      .listRowSeparator(.hidden)
    }
  }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

@MainActor
struct GalleryMediaCell: View {
  let mediaStatus: MediaStatus
  let routerPath: RouterPath
  
  var body: some View {
    GeometryReader { proxy in
      if let url = mediaStatus.attachment.url {
        Group {
          switch mediaStatus.attachment.supportedType {
          case .image:
            LazyImage(url: url, transaction: Transaction(animation: .easeIn)) { state in
              if let image = state.image {
                image
                  .resizable()
                  .scaledToFill()
                  .frame(width: proxy.size.width, height: proxy.size.width)
              } else {
                ProgressView()
                  .frame(width: proxy.size.width, height: proxy.size.width)
              }
            }
            .processors([.resize(size: proxy.size)])
            .transition(.opacity)
          case .gifv, .video:
            MediaUIAttachmentVideoView(viewModel: .init(url: url))
          default:
            EmptyView()
          }
        }
        .onTapGesture {
          routerPath.navigate(to: .statusDetailWithStatus(status: mediaStatus.status))
        }
      }
    }
    .clipped()
    .aspectRatio(1, contentMode: .fit)
  }
}

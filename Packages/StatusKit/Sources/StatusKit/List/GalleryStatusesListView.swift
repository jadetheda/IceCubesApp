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
    let columns = UserPreferences.shared.galleryColumns
    
    // Distribute items into columns round-robin
    var columnItems: [[MediaStatus]] = Array(repeating: [], count: columns)
    for (index, status) in mediaStatuses.enumerated() {
        columnItems[index % columns].append(status)
    }
    
    HStack(alignment: .top, spacing: 4) {
      ForEach(0..<columns, id: \.self) { colIndex in
        LazyVStack(spacing: 4) {
          ForEach(columnItems[colIndex]) { status in
            GalleryMediaCell(mediaStatus: status, routerPath: routerPath)
              .onAppear { fetcher.statusDidAppear(status: status.status) }
              .onDisappear { fetcher.statusDidDisappear(status: status.status) }
          }
        }
      }
    }
    .padding(.horizontal, 4)
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
    let isSquare = UserPreferences.shared.galleryCropToSquare
    if let url = mediaStatus.attachment.url {
      Group {
        switch mediaStatus.attachment.supportedType {
        case .image:
          LazyImage(url: url, transaction: Transaction(animation: .easeIn)) { state in
            if let image = state.image {
              image
                .resizable()
                .scaledToFill()
            } else {
              ZStack {
                Color.secondary.opacity(0.1)
                ProgressView()
              }
            }
          }
          .transition(.opacity)
        case .gifv, .video:
          MediaUIAttachmentVideoView(viewModel: .init(url: url))
        default:
          EmptyView()
        }
      }
      .modifier(GalleryAspectRatioModifier(isSquare: isSquare))
      .clipped()
      .contentShape(Rectangle())
      .onTapGesture {
        routerPath.navigate(to: .statusDetailWithStatus(status: mediaStatus.status))
      }
    }
  }
}

struct GalleryAspectRatioModifier: ViewModifier {
    let isSquare: Bool
    
    func body(content: Content) -> some View {
        if isSquare {
            content.aspectRatio(1, contentMode: .fill)
        } else {
            // Masonry mode limits height to something reasonable without squishing it to 1:1,
            // or just scales to fit the width. For Waterfall, the width is dictated by the column,
            // so we just let it aspect fit/fill naturally.
            // A max height prevents extremely tall single images from breaking the flow too badly.
            content
                .scaledToFit()
                .frame(maxHeight: 400)
        }
    }
}

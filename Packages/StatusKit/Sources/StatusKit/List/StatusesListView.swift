import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

@MainActor
public struct StatusesListView<Fetcher>: View where Fetcher: StatusesFetcher {
  @Environment(Theme.self) private var theme
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var fetcher: Fetcher
  // Whether this status is on a remote local timeline (many actions are unavailable if so)
  private let isRemote: Bool
  private let routerPath: RouterPath
  private let client: MastodonClient
  private let filterContext: Filter.Context?
  private let isForceGalleryMode: Bool

  public init(
    fetcher: Fetcher,
    client: MastodonClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    filterContext: Filter.Context? = nil,
    isForceGalleryMode: Bool = false
  ) {
    _fetcher = .init(initialValue: fetcher)
    self.isRemote = isRemote
    self.client = client
    self.routerPath = routerPath
    self.filterContext = filterContext
    self.isForceGalleryMode = isForceGalleryMode
  }

  public var body: some View {
    if isForceGalleryMode {
      galleryBody
    } else {
      listBody
    }
  }

  @ViewBuilder
  private var listBody: some View {
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
        StatusRowView(
          viewModel: StatusRowViewModel(
            status: status,
            client: client,
            routerPath: routerPath,
            isRemote: isRemote,
            filterContext: filterContext),
          context: .timeline
        )
        .onAppear {
          fetcher.statusDidAppear(status: status)
        }
        .onDisappear {
          fetcher.statusDidDisappear(status: status)
        }
      }
      makeNextPageRow(nextPageState: nextPageState)

    case .displayWithGaps(let items, let nextPageState):
      ForEach(items) { item in
        ZStack {
          switch item {
          case .status(let status):
            StatusRowView(
              viewModel: StatusRowViewModel(
                status: status,
                client: client,
                routerPath: routerPath,
                isRemote: isRemote,
                filterContext: filterContext),
              context: .timeline
            )
            .onAppear {
              fetcher.statusDidAppear(status: status)
            }
            .onDisappear {
              fetcher.statusDidDisappear(status: status)
            }

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

  @ViewBuilder
  private func makeBackgroundColorFor(status: Status?) -> some View {
    if let status {
      if status.visibility == .direct {
        theme.tintColor.opacity(0.15)
      } else if status.mentions.first(where: { $0.id == CurrentAccount.shared.account?.id }) != nil
      {
        theme.secondaryBackgroundColor
      } else {
        theme.primaryBackgroundColor
      }
    } else {
      theme.primaryBackgroundColor
    }
  }
  @ViewBuilder
  private var galleryBody: some View {
    switch fetcher.statusesState {
        case .loading:
          let columns = UserPreferences.shared.galleryColumns
          let itemsPerColumn = horizontalSizeClass == .regular ? 6 : 4
          // Provide stable fake heights so the placeholders don't jitter on re-evaluation
          let isSquare = UserPreferences.shared.galleryCropToSquare
          let placeholderRatios: [CGFloat] = isSquare ? [1.0] : [1.0, 1.5, 0.8, 1.2, 0.9, 1.3]
          HStack(alignment: .top, spacing: 4) {
            ForEach(0..<columns, id: \.self) { colIndex in
              LazyVStack(spacing: 0) {
                ForEach(0..<itemsPerColumn, id: \.self) { rowIndex in
                  RoundedRectangle(cornerRadius: UserPreferences.shared.galleryRoundCorners ? 8 : 0)
                    .fill(theme.secondaryBackgroundColor)
                    .aspectRatio(placeholderRatios[(colIndex + rowIndex) % placeholderRatios.count], contentMode: .fit)
                    .padding(.bottom, 4)
                }
              }
              .frame(minWidth: 0, maxWidth: .infinity)
            }
          }
          .frame(maxWidth: .infinity)
          .redacted(reason: .placeholder)
          .allowsHitTesting(false)
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
          let items = statuses.map { TimelineItem.status($0) }
          makeGrid(for: items, nextPageState: nextPageState)
        case .displayWithGaps(let items, let nextPageState):
          makeGrid(for: items, nextPageState: nextPageState)
        }
      }

  private struct GalleryNode: Identifiable, Equatable {
      let id: String
      let mediaStatus: MediaStatus?
      let anchorIds: [String]
      
      static func == (lhs: GalleryNode, rhs: GalleryNode) -> Bool {
        lhs.id == rhs.id
      }
    }
  
    private struct GalleryChunk: Identifiable {
      var id: String {
        if let gap = gap { return gap.id }
        return items.last?.id ?? UUID().uuidString
      }
      var items: [TimelineItem] = []
      var gap: TimelineGap? = nil
      var isGap: Bool { gap != nil }
    }

    private func chunkItems(_ items: [TimelineItem]) -> [GalleryChunk] {
      var chunks: [GalleryChunk] = []
      var currentChunk = GalleryChunk()
      
      for item in items {
        switch item {
        case .gap(let gap):
          if !currentChunk.items.isEmpty {
            chunks.append(currentChunk)
            currentChunk = GalleryChunk()
          }
          chunks.append(GalleryChunk(gap: gap))
        case .status(let status):
          currentChunk.items.append(item)
          if status.id.hashValue % 18 == 0 {
            chunks.append(currentChunk)
            currentChunk = GalleryChunk()
          }
        }
      }
      
      if !currentChunk.items.isEmpty {
        chunks.append(currentChunk)
      }
      
      return chunks
    }
  
  
  

    @ViewBuilder
    private func makeGalleryNextPageRow(nextPageState: StatusesState.PagingState) -> some View {
      if nextPageState == .hasNextPage {
        NextPageView {
          try await fetcher.fetchNextPage()
        }
        .padding(.vertical)
        .listRowBackground(theme.primaryBackgroundColor)
      }
    }
  
    @ViewBuilder
    private func makeGrid(for items: [TimelineItem], nextPageState: StatusesState.PagingState) -> some View {
      let chunks = chunkItems(items)
      
      ForEach(chunks) { chunk in
        VStack(spacing: 0) {
          if chunk.isGap, let gap = chunk.gap {
            if let loadGap = fetcher as? GapLoadingFetcher {
              TimelineGapView(gap: gap) {
                await loadGap.loadGap(gap: gap)
              }
              .padding(.horizontal, .layoutPadding)
              .padding(.vertical, 8)
            }
          } else {
            makeGridChunk(for: chunk.items)
          }
        }
        .listRowBackground(theme.primaryBackgroundColor)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      }
      .task(id: items.count) {
        let mediaCount = items.filter { if case .status(let status) = $0 { return !status.asMediaStatus.isEmpty }; return false }.count
        let columns = UserPreferences.shared.galleryColumns
        let itemsPerColumn = horizontalSizeClass == .regular ? 6 : 4
        let targetMediaCount = columns * itemsPerColumn
        
        if mediaCount < targetMediaCount && nextPageState == .hasNextPage {
          try? await fetcher.fetchNextPage()
        }
      }
      
      makeGalleryNextPageRow(nextPageState: nextPageState)
    }
  
    private func computeGalleryNodes(for items: [TimelineItem]) -> [GalleryNode] {
      var galleryNodes: [GalleryNode] = []
      var currentAnchors: [String] = []
  
      for item in items {
        switch item {
        case .status(let status):
          let mediaStatuses = status.asMediaStatus
          if mediaStatuses.isEmpty {
            currentAnchors.append(status.id)
          } else {
            for (index, mediaStatus) in mediaStatuses.enumerated() {
              var anchors = index == 0 ? currentAnchors : []
              if index == 0 { anchors.append(status.id) }
              galleryNodes.append(GalleryNode(
                id: mediaStatus.id,
                mediaStatus: mediaStatus,
                anchorIds: anchors
              ))
              if index == 0 { currentAnchors = [] }
            }
          }
        case .gap:
          break
        }
      }
  
      if !currentAnchors.isEmpty {
        galleryNodes.append(GalleryNode(
          id: currentAnchors.first!,
          mediaStatus: nil,
          anchorIds: currentAnchors
        ))
      }
  
      return galleryNodes
    }
  
    private func computeColumnItems(from galleryNodes: [GalleryNode], columns: Int) -> [[GalleryNode]] {
      var items: [[GalleryNode]] = Array(repeating: [], count: columns)
      var columnHeights: [CGFloat] = Array(repeating: 0, count: columns)
  
      var currentIndex = 0
      for node in galleryNodes {
        let targetColIndex: Int
  
        if let mediaStatus = node.mediaStatus {
          if UserPreferences.shared.galleryOptimizeItemLayout {
            var shortestColIndex = 0
            var shortestHeight = columnHeights[0]
  
            for i in 1..<columns {
              if columnHeights[i] < shortestHeight {
                shortestHeight = columnHeights[i]
                shortestColIndex = i
              }
            }
            targetColIndex = shortestColIndex
          } else {
            targetColIndex = currentIndex % columns
          }
  
          items[targetColIndex].append(node)
  
          let isSquare = UserPreferences.shared.galleryCropToSquare
          let actualRatio = mediaStatus.attachment.aspectRatio
          var aspectRatio = isSquare ? 1.0 : (actualRatio ?? 1.0)
          if aspectRatio <= 0 { aspectRatio = 1.0 }
          columnHeights[targetColIndex] += (1.0 / aspectRatio) + 0.1
          currentIndex += 1
        } else {
          // Trailing anchors with no media
          items[0].append(node)
        }
      }
  
      return items
    }
  
    @ViewBuilder
    private func makeGridChunk(for items: [TimelineItem]) -> some View {
      let galleryNodes = computeGalleryNodes(for: items)
      let columns = UserPreferences.shared.galleryColumns
      let columnItems = computeColumnItems(from: galleryNodes, columns: columns)
  
      HStack(alignment: .top, spacing: 4) {
        ForEach(0..<columns, id: \.self) { colIndex in
          LazyVStack(spacing: 0) {
            ForEach(columnItems[colIndex]) { node in
              VStack(spacing: 0) {
                ForEach(node.anchorIds, id: \.self) { anchorId in
                  Color.clear
                    .frame(height: 0)
                    .id(anchorId)
                }
                if let mediaStatus = node.mediaStatus {
                  GalleryMediaCell(
                    mediaStatus: mediaStatus,
                    routerPath: routerPath,
                    client: client,
                    isRemote: isRemote,
                    filterContext: filterContext
                  )
                  .id(mediaStatus.id)
                  .padding(.bottom, 4)
                  .onAppear { fetcher.statusDidAppear(status: mediaStatus.status) }
                  .onDisappear { fetcher.statusDidDisappear(status: mediaStatus.status) }
                }
              }
            }
          }
          .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
      }
      .frame(maxWidth: .infinity)
      .clipped()
      .padding(.horizontal, UserPreferences.shared.galleryAddThinMargins ? 4 : 0)
    }
}

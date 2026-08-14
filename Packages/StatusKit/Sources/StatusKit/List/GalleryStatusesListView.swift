import DesignSystem
import Env
import Models
import NetworkClient
import MediaUI
import NukeUI
import SwiftUI

@MainActor
public struct GalleryStatusesListView<Fetcher>: View where Fetcher: StatusesFetcher {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var fetcher: Fetcher
  private let isRemote: Bool
  private let client: MastodonClient
  private let filterContext: Filter.Context?

  public init(fetcher: Fetcher, client: MastodonClient, routerPath: RouterPath, isRemote: Bool = false, filterContext: Filter.Context? = nil) {
    _fetcher = .init(initialValue: fetcher)
    self.isRemote = isRemote
    self.client = client
    self.filterContext = filterContext
  }

  public var body: some View {
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
      return items.first?.id ?? UUID().uuidString
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
      case .status:
        currentChunk.items.append(item)
      }
    }
    
    if !currentChunk.items.isEmpty {
      chunks.append(currentChunk)
    }
    
    return chunks
  }



  private enum GallerySegment: Identifiable {
    case grid(id: String, statuses: [Status])
    case gap(TimelineGap)

    var id: String {
      switch self {
      case .grid(let id, _):
        return id
      case .gap(let gap):
        return gap.id
      }
    }
  }

  private func makeSegments(from items: [TimelineItem]) -> [GallerySegment] {
    var segments: [GallerySegment] = []
    var currentStatuses: [Status] = []
    
    for item in items {
      switch item {
      case .status(let status):
        currentStatuses.append(status)
      case .gap(let gap):
        if !currentStatuses.isEmpty {
          segments.append(.grid(id: currentStatuses.first?.id ?? UUID().uuidString, statuses: currentStatuses))
          currentStatuses = []
        }
        segments.append(.gap(gap))
      }
    }

    if !currentStatuses.isEmpty {
      segments.append(.grid(id: currentStatuses.first?.id ?? UUID().uuidString, statuses: currentStatuses))
    }

    return segments
  }

  @ViewBuilder
  private func makeNextPageRow(nextPageState: StatusesState.PagingState) -> some View {
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
          if let gapLoader = fetcher as? GapLoadingFetcher {
            TimelineGapView(gap: gap) {
              await gapLoader.loadGap(gap: gap)
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
    
    makeNextPageRow(nextPageState: nextPageState)
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

@MainActor
public struct GalleryMediaCell: View {
  public let mediaStatus: MediaStatus
  public let routerPath: RouterPath
  public let client: MastodonClient
  public let isRemote: Bool
  public let filterContext: Filter.Context?

  public init(mediaStatus: MediaStatus, routerPath: RouterPath, client: MastodonClient, isRemote: Bool, filterContext: Filter.Context?) {
    self.mediaStatus = mediaStatus
    self.routerPath = routerPath
    self.client = client
    self.isRemote = isRemote
    self.filterContext = filterContext
  }

  @State private var viewModel: StatusRowViewModel?
  @State private var showSelectableText: Bool = false
  @State private var isBlockConfirmationPresented = false
  @State private var isShareAsImageSheetPresented = false
  @State private var autoFallbackTriggered = false
  @State private var imageLoaded = false
  @State private var loadTask: Task<Void, Never>? = nil

  public var body: some View {
    let isSquare = UserPreferences.shared.galleryCropToSquare
    let isIceShrimp = mediaStatus.status.account.url?.absoluteString.lowercased().contains("iceshrimp") == true
    let fallback = UserPreferences.shared.remoteMediaFallbackOnFail || (UserPreferences.shared.useIceShrimpWorkarounds && isIceShrimp)
    let effectiveUseRemoteMedia = isRemote || UserPreferences.shared.remoteMediaAlwaysForce || autoFallbackTriggered
    
    let info = mediaStatus.attachment.displayInfo(useRemoteMedia: effectiveUseRemoteMedia, fallbackOnFail: fallback, neverLoadVideo: false, isIceShrimp: UserPreferences.shared.useIceShrimpWorkarounds && isIceShrimp)
    let resolvedUrl = info?.url
    let fallbackUrl = info?.fallbackUrl
    let resolvedType = info?.type

    if let url = resolvedUrl {
      Button {
        if let viewModel {
          viewModel.navigateToDetail()
        } else {
          routerPath.navigate(to: .statusDetailWithStatus(status: mediaStatus.status))
        }
      } label: {
        Group {
          switch resolvedType {
          case .image:
            if mediaStatus.attachment.aspectRatio == nil && !isSquare {
              LazyImage(url: autoFallbackTriggered ? (fallbackUrl ?? url) : url) { state in
                if let image = state.image {
                  image
                    .resizable()
                    .scaledToFit()
                    .onAppear {
                      DispatchQueue.main.async {
                        if !imageLoaded { imageLoaded = true }
                      }
                    }
                } else if state.error != nil {
                  Color.secondary.opacity(0.1)
                    .aspectRatio(1, contentMode: .fit)
                    .onAppear {
                      if !autoFallbackTriggered && fallbackUrl != nil {
                        DispatchQueue.main.async { autoFallbackTriggered = true }
                      }
                    }
                } else {
                  ZStack {
                    Color.secondary.opacity(0.1)
                    ProgressView()
                  }
                  .aspectRatio(1, contentMode: .fit)
                }
              }
              .transition(.opacity)
            } else {
              LazyResizableImage(url: url, fallbackUrl: fallbackUrl) { state in
                if let image = state.image {
                  image
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                      DispatchQueue.main.async {
                        if !imageLoaded { imageLoaded = true }
                      }
                    }
                } else {
                  ZStack {
                    Color.secondary.opacity(0.1)
                    ProgressView()
                  }
                }
              }
              .transition(.opacity)
            }
          case .gifv, .video:
            MediaUIAttachmentVideoView(viewModel: .init(url: url, fallbackUrl: fallbackUrl))
              .allowsHitTesting(false)
          default:
            EmptyView()
          }
        }
        .modifier(GalleryAspectRatioModifier(isSquare: isSquare, aspectRatio: mediaStatus.attachment.aspectRatio))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: UserPreferences.shared.galleryRoundCorners ? 8 : 0))
        .contentShape(RoundedRectangle(cornerRadius: UserPreferences.shared.galleryRoundCorners ? 8 : 0))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: UserPreferences.shared.galleryRoundCorners ? 8 : 0))
        .contextMenu {
          if let viewModel {
            StatusRowContextMenu(
              viewModel: viewModel,
              showTextForSelection: $showSelectableText,
              isBlockConfirmationPresented: $isBlockConfirmationPresented,
              isShareAsImageSheetPresented: $isShareAsImageSheetPresented
            )
            .environment(StatusDataControllerProvider.shared.dataController(for: viewModel.finalStatus, client: client))
            .tint(.primary)
            .onAppear {
              Task {
                await viewModel.loadAuthorRelationship()
              }
            }
          } else {
            ProgressView()
          }
        }
      }
      .buttonStyle(.plain)
      .onAppear {
        if viewModel == nil {
          viewModel = StatusRowViewModel(
            status: mediaStatus.status,
            client: client,
            routerPath: routerPath,
            isRemote: isRemote,
            filterContext: filterContext
          )
        }
        if UserPreferences.shared.remoteMediaAutoFallback && !effectiveUseRemoteMedia {
            loadTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(UserPreferences.shared.remoteMediaAutoFallbackDelay * 1_000_000_000.0))
                if !Task.isCancelled {
                    if !imageLoaded {
                        autoFallbackTriggered = true
                    }
                }
            }
        }
      }
      .onDisappear {
          loadTask?.cancel()
      }
      .onChange(of: imageLoaded) { _, newValue in
          if newValue {
              loadTask?.cancel()
          }
      }
      .sheet(isPresented: $showSelectableText) {
        if let viewModel {
          let content =
            viewModel.status.reblog?.content.asSafeMarkdownAttributedString
            ?? viewModel.status.content.asSafeMarkdownAttributedString
          StatusRowSelectableTextView(content: content)
        }
      }
      .alert(
        isPresented: Binding(
          get: { viewModel?.showDeleteAlert ?? false },
          set: { viewModel?.showDeleteAlert = $0 }
        ),
        content: {
          Alert(
            title: Text("status.action.delete.confirm.title"),
            message: Text("status.action.delete.confirm.message"),
            primaryButton: .destructive(
              Text("status.action.delete")
            ) {
              Task {
                if let viewModel {
                  try? await viewModel.delete()
                }
              }
            },
            secondaryButton: .cancel()
          )
        }
      )
      .confirmationDialog(
        "",
        isPresented: $isBlockConfirmationPresented
      ) {
        Button("account.action.block", role: .destructive) {
          Task {
            do {
              if let viewModel {
                let operationAccount = viewModel.status.reblog?.account ?? viewModel.status.account
                viewModel.authorRelationship = try await client.post(
                  endpoint: Accounts.block(id: operationAccount.id))
              }
            } catch {}
          }
        }
      }
      .environment(
        StatusDataControllerProvider.shared.dataController(
          for: viewModel?.finalStatus ?? mediaStatus.status,
          client: client)
      )
    }
  }
}

public struct GalleryAspectRatioModifier: ViewModifier {
  public let isSquare: Bool
  public let aspectRatio: CGFloat?
  
  public init(isSquare: Bool, aspectRatio: CGFloat?) {
    self.isSquare = isSquare
    self.aspectRatio = aspectRatio
      }

  public func body(content: Content) -> some View {
    if isSquare {
      Color.clear
        .aspectRatio(1, contentMode: .fit)
        .overlay {
          content
        }
        .clipped()
    } else if let aspectRatio = aspectRatio {
      Color.clear
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay {
          content
        }
        .clipped()
    } else {
      content
    }
  }
}

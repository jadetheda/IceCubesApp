import DesignSystem
import Env
import Foundation
import MediaUI
import Models
import NetworkClient
import NukeUI
import SwiftUI

/// Describes how a subview inside `GalleryMasonryLayout` should be positioned.
public nonisolated enum GalleryLayoutItemKind: Sendable, Equatable {
  /// A media cell with a deterministic aspect ratio (`width / height`), placed into the target masonry column.
  case media(aspectRatio: CGFloat)
  /// A full-width banner or timeline gap loader that spans across all columns.
  case fullWidth
  /// A zero-height scroll anchor placed at the current minimum column offset without adding spacing.
  case anchor
}

/// Layout value key used by `GalleryMasonryLayout` to classify child views without nested `LazyVStack` wrappers.
public nonisolated struct GalleryLayoutItemKindKey: LayoutValueKey {
  public static let defaultValue: GalleryLayoutItemKind = .media(aspectRatio: 1.0)
}

public extension View {
  /// Marks a subview's role inside `GalleryMasonryLayout`.
  func galleryLayoutItemKind(_ kind: GalleryLayoutItemKind) -> some View {
    layoutValue(key: GalleryLayoutItemKindKey.self, value: kind)
  }
}

/// A deterministic 2D Waterfall/Masonry `Layout` that places items continuously based on running column Y-offsets.
///
/// Why this replaces `HStack { LazyVStack }`:
/// 1. Eliminates double-nested `LazyVStack` virtualization conflicts inside `ScrollView` and `UICollectionView` (`List` rows).
/// 2. Eliminates the `.frame(maxHeight: .infinity)` / `Spacer` column-stretching bug where shorter `LazyVStack` columns
///    accepted the tallest column's height and vertically centered or separated their children with massive empty voids.
/// 3. Computes exact pixel heights from `columnWidth / aspectRatio` (with `4pt` real pixel spacing rather than fake `+ 0.1`
///    normalized ratios), guaranteeing zero height drift between column assignment math and rendered cells.
public nonisolated struct GalleryMasonryLayout: Layout {
  public let columns: Int
  public let spacing: CGFloat
  public let optimizeLayout: Bool

  public struct CacheData {
    var width: CGFloat = -1
    var subviewCount: Int = -1
    var columns: Int = -1
    var spacing: CGFloat = -1
    var optimizeLayout: Bool = true
    var frames: [CGRect] = []
    var totalHeight: CGFloat = 0
  }

  public init(columns: Int, spacing: CGFloat = 4, optimizeLayout: Bool = true) {
    self.columns = max(1, columns)
    self.spacing = spacing
    self.optimizeLayout = optimizeLayout
  }

  public func makeCache(subviews: Subviews) -> CacheData {
    CacheData()
  }

  public func updateCache(_ cache: inout CacheData, subviews: Subviews) {
    cache.width = -1
  }

  public func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CacheData
  ) -> CGSize {
    guard !subviews.isEmpty else { return .zero }
    let resolvedWidth = resolveAvailableWidth(from: proposal.width)
    computeIfNeeded(availableWidth: resolvedWidth, subviews: subviews, cache: &cache)
    return CGSize(width: resolvedWidth, height: cache.totalHeight)
  }

  public func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CacheData
  ) {
    guard !subviews.isEmpty else { return }
    let resolvedWidth = bounds.width > 0 ? bounds.width : resolveAvailableWidth(from: proposal.width)
    computeIfNeeded(availableWidth: resolvedWidth, subviews: subviews, cache: &cache)

    for (index, subview) in subviews.enumerated() {
      guard index < cache.frames.count else { break }
      let frame = cache.frames[index]
      let origin = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
      let itemProposal = ProposedViewSize(width: frame.width, height: frame.height)
      subview.place(at: origin, anchor: .topLeading, proposal: itemProposal)
    }
  }

  private func resolveAvailableWidth(from proposedWidth: CGFloat?) -> CGFloat {
    if let proposedWidth {
      if proposedWidth.isFinite {
        if proposedWidth > 0 {
          return proposedWidth
        }
      }
    }
    return 390
  }

  private func computeIfNeeded(
    availableWidth: CGFloat,
    subviews: Subviews,
    cache: inout CacheData
  ) {
    let safeColumns = max(1, columns)
    if abs(cache.width - availableWidth) < 0.5 {
      if cache.subviewCount == subviews.count {
        if cache.columns == safeColumns {
          if cache.spacing == spacing {
            if cache.optimizeLayout == optimizeLayout {
              return
            }
          }
        }
      }
    }

    let totalHorizontalSpacing = CGFloat(safeColumns - 1) * spacing
    let usableWidth = max(0, availableWidth - totalHorizontalSpacing)
    let columnWidth = usableWidth / CGFloat(safeColumns)

    var columnHeights = Array(repeating: CGFloat(0), count: safeColumns)
    var columnHasItems = Array(repeating: false, count: safeColumns)
    var frames: [CGRect] = []
    frames.reserveCapacity(subviews.count)
    var mediaIndex = 0

    for subview in subviews {
      let kind = subview[GalleryLayoutItemKindKey.self]
      switch kind {
      case .anchor:
        let minY = columnHeights.min() ?? 0
        frames.append(CGRect(x: 0, y: minY, width: 0, height: 0))

      case .fullWidth:
        var maxY: CGFloat = 0
        for col in 0..<safeColumns {
          if columnHasItems[col] {
            let bottom = max(0, columnHeights[col] - spacing)
            if bottom > maxY {
              maxY = bottom
            }
          } else if columnHeights[col] > maxY {
            maxY = columnHeights[col]
          }
        }
        if maxY > 0 {
          maxY += spacing
        }
        let fullProposal = ProposedViewSize(width: availableWidth, height: nil)
        let measured = subview.sizeThatFits(fullProposal)
        let h = max(0, measured.height)
        frames.append(CGRect(x: 0, y: maxY, width: availableWidth, height: h))
        let nextY = maxY + h + spacing
        for col in 0..<safeColumns {
          columnHeights[col] = nextY
          columnHasItems[col] = false
        }

      case .media(let aspectRatio):
        let targetCol: Int
        if optimizeLayout {
          var shortestCol = 0
          var shortestHeight = columnHeights[0]
          for col in 1..<safeColumns {
            if columnHeights[col] < shortestHeight {
              shortestHeight = columnHeights[col]
              shortestCol = col
            }
          }
          targetCol = shortestCol
        } else {
          targetCol = mediaIndex % safeColumns
        }

        let safeRatio = aspectRatio > 0 ? aspectRatio : 1.0
        let itemHeight = columnWidth / safeRatio
        let x = CGFloat(targetCol) * (columnWidth + spacing)
        let y = columnHeights[targetCol]
        frames.append(CGRect(x: x, y: y, width: columnWidth, height: itemHeight))

        columnHeights[targetCol] = y + itemHeight + spacing
        columnHasItems[targetCol] = true
        mediaIndex += 1
      }
    }

    var maxBottom: CGFloat = 0
    for col in 0..<safeColumns {
      if columnHasItems[col] {
        let bottom = max(0, columnHeights[col] - spacing)
        if bottom > maxBottom {
          maxBottom = bottom
        }
      } else if columnHeights[col] > maxBottom {
        let bottom = max(0, columnHeights[col] - spacing)
        if bottom > maxBottom {
          maxBottom = bottom
        }
      }
    }

    cache.width = availableWidth
    cache.subviewCount = subviews.count
    cache.columns = safeColumns
    cache.spacing = spacing
    cache.optimizeLayout = optimizeLayout
    cache.frames = frames
    cache.totalHeight = maxBottom
  }
}

@MainActor
public struct GalleryStatusesListView: View {
  @Environment(Theme.self) private var theme
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(RouterPath.self) private var routerPath

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var fetcher: any StatusesFetcher
  private let isRemote: Bool
  private let client: FediverseClient
  private let filterContext: Filter.Context?

  public init(
    fetcher: any StatusesFetcher,
    client: FediverseClient,
    routerPath: RouterPath,
    isRemote: Bool = false,
    filterContext: Filter.Context? = nil
  ) {
    _fetcher = .init(initialValue: fetcher)
    self.isRemote = isRemote
    self.client = client
    self.filterContext = filterContext
  }

  private var columns: Int { max(1, userPreferences.galleryColumns) }
  private var itemsPerColumn: Int { horizontalSizeClass == .regular ? 6 : 4 }
  private var totalPlaceholderCount: Int { columns * itemsPerColumn }
  private var isSquare: Bool { userPreferences.galleryCropToSquare }
  private var optimizeLayout: Bool { userPreferences.galleryOptimizeItemLayout }
  private var placeholderRatios: [CGFloat] { isSquare ? [1.0] : [1.0, 1.5, 0.8, 1.2, 0.9, 1.3] }
  private var cornerRadius: CGFloat { userPreferences.galleryRoundCorners ? 8 : 0 }
  private var horizontalPadding: CGFloat { userPreferences.galleryAddThinMargins ? 4 : 0 }

  private func placeholderRatio(at index: Int) -> CGFloat {
    let ratios = placeholderRatios
    guard !ratios.isEmpty else { return 1.0 }
    return ratios[index % ratios.count]
  }

  public var body: some View {
    switch fetcher.statusesState {
    case .loading:
      loadingSkeletonGrid
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
      makeGrid(for: statuses.map { TimelineItem.status($0) }, nextPageState: nextPageState)
    case .displayWithGaps(let items, let nextPageState):
      makeGrid(for: items, nextPageState: nextPageState)
    }
  }

  @ViewBuilder
  private var loadingSkeletonGrid: some View {
    GalleryMasonryLayout(
      columns: columns,
      spacing: 4,
      optimizeLayout: optimizeLayout
    ) {
      ForEach(0..<totalPlaceholderCount, id: \.self) { index in
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(theme.secondaryBackgroundColor)
          .aspectRatio(placeholderRatio(at: index), contentMode: .fit)
          .galleryLayoutItemKind(.media(aspectRatio: placeholderRatio(at: index)))
      }
    }
    .padding(.horizontal, horizontalPadding)
    .frame(maxWidth: .infinity)
    .redacted(reason: .placeholder)
    .allowsHitTesting(false)
    .listRowBackground(theme.primaryBackgroundColor)
    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    .listRowSeparator(.hidden)
  }

  private struct GalleryNode: Identifiable, Equatable {
    let id: String
    let mediaStatus: MediaStatus?
    let anchorIds: [String]
    let aspectRatio: CGFloat

    static func == (lhs: GalleryNode, rhs: GalleryNode) -> Bool {
      lhs.id == rhs.id && lhs.aspectRatio == rhs.aspectRatio
    }
  }

  private struct GalleryChunk: Identifiable {
    let id: String
    var items: [TimelineItem] = []
    var gap: TimelineGap? = nil
  }

  private func chunkItems(_ items: [TimelineItem]) -> [GalleryChunk] {
    var chunks: [GalleryChunk] = []
    var currentItems: [TimelineItem] = []
    var usedChunkIds = Set<String>()

    for (index, item) in items.enumerated() {
      switch item {
      case .gap(let gap):
        if !currentItems.isEmpty {
          let rawId = currentItems.first?.id ?? "chunk-\(index)"
          let chunkId = usedChunkIds.insert(rawId).inserted ? rawId : "\(rawId)-\(index)"
          chunks.append(GalleryChunk(id: chunkId, items: currentItems, gap: nil))
          currentItems = []
        }
        let gapId = usedChunkIds.insert(gap.id).inserted ? gap.id : "\(gap.id)-\(index)"
        chunks.append(GalleryChunk(id: gapId, items: [], gap: gap))
      case .status:
        currentItems.append(item)
      }
    }

    if !currentItems.isEmpty {
      let rawId = currentItems.first?.id ?? "chunk-tail"
      let chunkId = usedChunkIds.insert(rawId).inserted ? rawId : "\(rawId)-tail"
      chunks.append(GalleryChunk(id: chunkId, items: currentItems, gap: nil))
    }

    return chunks
  }

  private func isStatusFiltered(_ status: Status) -> Bool {
    if let filterContext {
      if status.isHidden(in: filterContext) { return true }
      if let reblog = status.reblog {
        if reblog.isHidden(in: filterContext) { return true }
      }
    } else {
      if status.isHidden { return true }
      if let reblog = status.reblog {
        if reblog.isHidden { return true }
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

  private func countVisibleMedia(in items: [TimelineItem]) -> Int {
    var total = 0
    for item in items {
      if case .status(let status) = item {
        if !isStatusFiltered(status) {
          total += status.asMediaStatus.count
        }
      }
    }
    return total
  }

  @ViewBuilder
  private func makeNextPageRow(nextPageState: StatusesState.PagingState) -> some View {
    if nextPageState == .hasNextPage {
      NextPageView {
        try await fetcher.fetchNextPage()
      }
      .padding(.vertical)
      .listRowBackground(theme.primaryBackgroundColor)
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      .listRowSeparator(.hidden)
    }
  }

  @ViewBuilder
  private func makeGrid(for items: [TimelineItem], nextPageState: StatusesState.PagingState) -> some View {
    ForEach(chunkItems(items)) { chunk in
      if let gap = chunk.gap {
        if let gapLoader = fetcher as? GapLoadingFetcher {
          TimelineGapView(gap: gap) {
            await gapLoader.loadGap(gap: gap)
          }
          .padding(.horizontal, .layoutPadding)
          .padding(.vertical, 8)
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          .listRowSeparator(.hidden)
        }
      } else {
        makeGridChunk(for: chunk.items)
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          .listRowSeparator(.hidden)
      }
    }
    .task(id: items.count) {
      let mediaCount = countVisibleMedia(in: items)
      if mediaCount == 0 {
        if nextPageState == .hasNextPage {
          try? await fetcher.fetchNextPage()
        }
      }
    }

    makeNextPageRow(nextPageState: nextPageState)
  }

  /// Converts a contiguous sequence of `TimelineItem`s into unique `GalleryNode`s.
  ///
  /// Guarantees:
  /// 1. Every `GalleryNode.id` is strictly unique across the chunk (even if a status was boosted
  ///    multiple times or duplicated in the initial seed).
  /// 2. Anchor IDs are deduplicated and never collide with `node.id`, preventing SwiftUI `ForEach`
  ///    identity collisions that previously caused missing cells and vertical voids.
  private func computeGalleryNodes(for items: [TimelineItem]) -> [GalleryNode] {
    var galleryNodes: [GalleryNode] = []
    var currentAnchors: [String] = []
    var usedIds = Set<String>()
    let cropSquare = isSquare

    for item in items {
      switch item {
      case .status(let status):
        if isStatusFiltered(status) {
          continue
        }
        let mediaStatuses = status.asMediaStatus
        if mediaStatuses.isEmpty {
          if usedIds.insert(status.id).inserted {
            currentAnchors.append(status.id)
          }
        } else {
          for (index, mediaStatus) in mediaStatuses.enumerated() {
            let baseId = mediaStatus.id
            let uniqueNodeId: String
            if usedIds.insert(baseId).inserted {
              uniqueNodeId = baseId
            } else {
              let compositeId = "\(status.id)-\(baseId)"
              if usedIds.insert(compositeId).inserted {
                uniqueNodeId = compositeId
              } else {
                let indexedId = "\(compositeId)-\(galleryNodes.count)"
                usedIds.insert(indexedId)
                uniqueNodeId = indexedId
              }
            }

            var anchors: [String] = []
            if index == 0 {
              anchors.append(contentsOf: currentAnchors)
              if status.id != uniqueNodeId {
                if usedIds.insert(status.id).inserted {
                  anchors.append(status.id)
                }
              }
              currentAnchors = []
            }

            let ratio = mediaStatus.attachment.galleryAspectRatio(isSquare: cropSquare)
            galleryNodes.append(
              GalleryNode(
                id: uniqueNodeId,
                mediaStatus: mediaStatus,
                anchorIds: anchors,
                aspectRatio: ratio
              )
            )
          }
        }
      case .gap:
        break
      }
    }

    if !currentAnchors.isEmpty {
      let firstAnchor = currentAnchors[0]
      let remainingAnchors = Array(currentAnchors.dropFirst())
      galleryNodes.append(
        GalleryNode(
          id: firstAnchor,
          mediaStatus: nil,
          anchorIds: remainingAnchors,
          aspectRatio: 1.0
        )
      )
    }

    return galleryNodes
  }

  @ViewBuilder
  private func makeGridChunk(for items: [TimelineItem]) -> some View {
    makeGridChunkView(nodes: computeGalleryNodes(for: items))
  }

  @ViewBuilder
  private func makeGridChunkView(nodes: [GalleryNode]) -> some View {
    GalleryMasonryLayout(
      columns: columns,
      spacing: 4,
      optimizeLayout: optimizeLayout
    ) {
      ForEach(nodes) { node in
        makeNodeView(for: node)
      }
    }
    .padding(.horizontal, horizontalPadding)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func makeNodeView(for node: GalleryNode) -> some View {
    if let mediaStatus = node.mediaStatus {
      GalleryMediaCell(
        mediaStatus: mediaStatus,
        routerPath: routerPath,
        client: client,
        isRemote: isRemote,
        filterContext: filterContext
      )
      .background(alignment: .top) {
        VStack(spacing: 0) {
          ForEach(node.anchorIds, id: \.self) { anchorId in
            Color.clear
              .frame(width: 1, height: 0)
              .id(anchorId)
          }
        }
      }
      .trackStatusVisibility(status: mediaStatus.status, fetcher: fetcher, requiresMediaToLoad: false)
      .galleryLayoutItemKind(.media(aspectRatio: node.aspectRatio))
    } else {
      VStack(spacing: 0) {
        ForEach(node.anchorIds, id: \.self) { anchorId in
          Color.clear
            .frame(width: 1, height: 0)
            .id(anchorId)
        }
      }
      .frame(width: 0, height: 0)
      .galleryLayoutItemKind(.anchor)
    }
  }
}

@MainActor
public struct GalleryMediaCell: View {
  public let mediaStatus: MediaStatus
  public let routerPath: RouterPath
  public let client: FediverseClient
  public let isRemote: Bool
  public let filterContext: Filter.Context?

  public init(
    mediaStatus: MediaStatus,
    routerPath: RouterPath,
    client: FediverseClient,
    isRemote: Bool,
    filterContext: Filter.Context?
  ) {
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
  @State private var staticPreviewFailed = false
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(\.statusOnMediaLoaded) private var statusOnMediaLoaded
  @State private var loadTask: Task<Void, Never>? = nil

  private var isSquare: Bool { userPreferences.galleryCropToSquare }

  /// Always returns a clamped, deterministic aspect ratio in `[0.5, 2.0]` (or `1.0` when square cropping
  /// is enabled or when server metadata is missing), ensuring cells never jump in height after download.
  private var effectiveAspectRatio: CGFloat {
    mediaStatus.attachment.galleryAspectRatio(isSquare: isSquare)
  }

  private var fallback: Bool { userPreferences.remoteMediaFallbackOnFail }

  private var effectiveUseRemoteMedia: Bool {
    if isRemote { return true }
    if userPreferences.remoteMediaAlwaysForce { return true }
    if autoFallbackTriggered { return true }
    return false
  }

  private var info: MediaAttachment.DisplayInfo? {
    mediaStatus.attachment.displayInfo(
      useRemoteMedia: effectiveUseRemoteMedia,
      fallbackOnFail: fallback,
      neverLoadVideo: false
    )
  }

  private var resolvedUrl: URL? { info?.url }
  private var fallbackUrl: URL? { info?.fallbackUrl }
  private var resolvedType: MediaAttachment.SupportedType? { info?.type }

  /// For image thumbnails and static video previews, prefer `previewUrl` (~30 KB) over `url` (multi-MB original).
  /// `info` already reflects `effectiveUseRemoteMedia` (including `autoFallbackTriggered`), so do not double-invert.
  private var resolvedThumbnailUrl: URL? {
    info?.previewUrl ?? info?.url
  }

  private var resolvedThumbnailFallbackUrl: URL? {
    info?.previewFallbackUrl ?? info?.fallbackUrl
  }

  private var shouldUseStaticVideoPreview: Bool {
    if staticPreviewFailed { return false }
    guard let info else { return false }
    return info.hasStaticPreviewImage
  }

  private var cornerRadius: CGFloat { userPreferences.galleryRoundCorners ? 8 : 0 }

  private var activeFinalStatus: Status {
    viewModel?.finalStatus ?? mediaStatus.status.reblogAsAsStatus ?? mediaStatus.status
  }

  private func ensureViewModel() {
    if viewModel == nil {
      viewModel = StatusRowViewModel(
        status: mediaStatus.status,
        client: client,
        routerPath: routerPath,
        isRemote: isRemote,
        filterContext: filterContext
      )
    }
  }

  private func markMediaLoaded() {
    if !imageLoaded {
      imageLoaded = true
    }
    statusOnMediaLoaded?()
  }

  @ViewBuilder
  private func makeThumbnailImage(url: URL, fallback: URL?, onFailure: (() -> Void)? = nil) -> some View {
    LazyResizableImage(url: url, fallbackUrl: fallback) { state in
      if let image = state.image {
        image
          .resizable()
          .scaledToFill()
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
          .clipped()
          .onAppear {
            markMediaLoaded()
          }
      } else if state.error != nil {
        ZStack {
          Color.secondary.opacity(0.1)
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
        .onAppear {
          onFailure?()
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

  @ViewBuilder
  private var videoBadgeOverlay: some View {
    ZStack(alignment: .bottomTrailing) {
      Color.clear
      HStack(spacing: 4) {
        if resolvedType == .gifv {
          Text("GIF")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
        } else {
          Image(systemName: "play.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
        }
      }
      .padding(.horizontal, 6)
      .padding(.vertical, 4)
      .background(.ultraThinMaterial)
      .clipShape(Capsule())
      .padding(6)
    }
    .allowsHitTesting(false)
  }

  @ViewBuilder
  private var cellMediaContent: some View {
    switch resolvedType {
    case .image:
      if let thumbUrl = resolvedThumbnailUrl {
        makeThumbnailImage(url: thumbUrl, fallback: resolvedThumbnailFallbackUrl)
      } else {
        Color.secondary.opacity(0.1)
      }
    case .gifv, .video:
      if shouldUseStaticVideoPreview, let thumbUrl = resolvedThumbnailUrl {
        makeThumbnailImage(
          url: thumbUrl,
          fallback: resolvedThumbnailFallbackUrl,
          onFailure: { staticPreviewFailed = true }
        )
        .overlay {
          videoBadgeOverlay
        }
      } else if let videoUrl = resolvedUrl {
        MediaUIAttachmentVideoView(
          viewModel: .init(
            url: videoUrl,
            fallbackUrl: fallbackUrl,
            onReady: {
              markMediaLoaded()
            }
          )
        )
        .allowsHitTesting(false)
      } else {
        Color.secondary.opacity(0.1)
      }
    default:
      Color.secondary.opacity(0.1)
    }
  }

  public var body: some View {
    if resolvedThumbnailUrl != nil || resolvedUrl != nil {
      Button {
        if let viewModel {
          viewModel.navigateToDetail()
        } else {
          routerPath.navigate(to: .statusDetailWithStatus(status: activeFinalStatus))
        }
      } label: {
        cellMediaContent
          .modifier(GalleryAspectRatioModifier(isSquare: isSquare, aspectRatio: effectiveAspectRatio))
          .clipped()
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
          .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
      }
      .buttonStyle(.borderless)
      .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
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
            .onAppear {
              ensureViewModel()
            }
        }
      }
      .onAppear {
        if userPreferences.remoteMediaAutoFallback {
          if !effectiveUseRemoteMedia {
            loadTask = Task {
              let delayNs = UInt64(userPreferences.remoteMediaAutoFallbackDelay * 1_000_000_000.0)
              try? await Task.sleep(nanoseconds: delayNs)
              if !Task.isCancelled {
                if !imageLoaded {
                  autoFallbackTriggered = true
                }
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
      .modifier(
        GalleryMediaCellModalsModifier(
          viewModel: viewModel,
          client: client,
          showSelectableText: $showSelectableText,
          isBlockConfirmationPresented: $isBlockConfirmationPresented,
          isShareAsImageSheetPresented: $isShareAsImageSheetPresented
        )
      )
      .environment(
        StatusDataControllerProvider.shared.dataController(
          for: activeFinalStatus,
          client: client
        )
      )
    }
  }
}

@MainActor
private struct GalleryMediaCellModalsModifier: ViewModifier {
  let viewModel: StatusRowViewModel?
  let client: FediverseClient
  @Binding var showSelectableText: Bool
  @Binding var isBlockConfirmationPresented: Bool
  @Binding var isShareAsImageSheetPresented: Bool

  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(CurrentAccount.self) private var currentAccount

  private func getSelectableTextContent(for viewModel: StatusRowViewModel) -> AttributedString {
    let reblogContent = viewModel.status.reblog?.content.asSafeMarkdownAttributedString
    let statusContent = viewModel.status.content.asSafeMarkdownAttributedString
    return reblogContent ?? statusContent
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $showSelectableText) {
        if let viewModel {
          StatusRowSelectableTextView(
            content: getSelectableTextContent(for: viewModel)
          )
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
      .sheet(isPresented: $isShareAsImageSheetPresented, content: makeShareAsImageSheet)
      .confirmationDialog(
        "Delete and redraft this post?",
        isPresented: Binding(
          get: { viewModel?.showRedraftAlert ?? false },
          set: { viewModel?.showRedraftAlert = $0 }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete and redraft", role: .destructive) {
          if let viewModel {
            let status = viewModel.status.reblogAsAsStatus ?? viewModel.status
            viewModel.routerPath.presentedSheet = .redraftStatusEditor(status: status)
          }
        }
        Button("Cancel", role: .cancel) {}
      }
      .confirmationDialog(
        "",
        isPresented: $isBlockConfirmationPresented
      ) {
        Button("account.action.block", role: .destructive) {
          Task {
            do {
              if let viewModel {
                let reblogAcct = viewModel.status.reblog?.account
                let acct = viewModel.status.account
                let operationAccount = reblogAcct ?? acct
                viewModel.authorRelationship = try await client.post(
                  endpoint: Accounts.block(id: operationAccount.id))
              }
            } catch {}
          }
        }
      }
  }

  private func makeShareAsImageSheet() -> some View {
    guard let viewModel else { return AnyView(EmptyView()) }
    let renderer = ImageRenderer(content: AnyView(shareCaptureView(viewModel: viewModel)))
    renderer.isOpaque = true
    renderer.scale = 3.0
    return AnyView(
      StatusRowShareAsImageView(
        viewModel: viewModel,
        renderer: renderer
      )
      .tint(theme.tintColor)
    )
  }

  private func shareCaptureView(viewModel: StatusRowViewModel) -> some View {
    HStack {
      StatusRowView(viewModel: viewModel, context: .timeline)
        .padding(8)
    }
    .background(theme.primaryBackgroundColor)
    .frame(width: 400)
    .environment(\.isInCaptureMode, true)
    .environment(theme)
    .environment(userPreferences)
    .environment(StatusDataControllerProvider.shared.dataController(for: viewModel.finalStatus, client: client))
    .environment(currentAccount)
  }
}

public struct GalleryAspectRatioModifier: ViewModifier {
  public let isSquare: Bool
  public let aspectRatio: CGFloat?

  public init(isSquare: Bool, aspectRatio: CGFloat?) {
    self.isSquare = isSquare
    self.aspectRatio = aspectRatio
  }

  private var resolvedAspectRatio: CGFloat {
    if isSquare { return 1.0 }
    if let aspectRatio {
      if aspectRatio > 0 {
        return min(max(aspectRatio, 0.5), 2.0)
      }
    }
    return 1.0
  }

  public func body(content: Content) -> some View {
    Color.clear
      .aspectRatio(resolvedAspectRatio, contentMode: .fit)
      .overlay {
        content
      }
      .clipped()
  }
}

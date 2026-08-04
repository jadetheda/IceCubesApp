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
    var gap: TimelineGap? = nil
    let anchorIds: [String]
    
    var isGap: Bool { gap != nil }
    
    static func == (lhs: GalleryNode, rhs: GalleryNode) -> Bool {
      lhs.id == rhs.id
    }
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
    let galleryNodes = computeGalleryNodes(for: items)
    let columns = UserPreferences.shared.galleryColumns
    let columnItems = computeColumnItems(from: galleryNodes, columns: columns)
    let mediaCount = galleryNodes.filter { $0.mediaStatus != nil }.count

    HStack(alignment: .top, spacing: 4) {
      ForEach(0..<columns, id: \.self) { colIndex in
        LazyVStack(spacing: 0) {
          ForEach(columnItems[colIndex]) { node in
            if node.isGap, let gap = node.gap {
              if let gapLoader = fetcher as? GapLoadingFetcher {
                TimelineGapView(gap: gap) {
                  await gapLoader.loadGap(gap: gap)
                }
                .padding(.horizontal, .layoutPadding)
                .padding(.vertical, 8)
              }
            } else {
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
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      }
    }
    .clipped()
    .padding(.horizontal, UserPreferences.shared.galleryAddThinMargins ? 4 : 0)
    .listRowBackground(theme.primaryBackgroundColor)
    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    .task(id: items.count) {
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
            galleryNodes.append(GalleryNode(
              id: mediaStatus.id,
              mediaStatus: mediaStatus,
              anchorIds: index == 0 ? currentAnchors : []
            ))
            if index == 0 { currentAnchors = [] }
          }
        }
      case .gap(let gap):
        galleryNodes.append(GalleryNode(
          id: gap.id,
          mediaStatus: nil,
          gap: gap,
          anchorIds: currentAnchors
        ))
        currentAnchors = []
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
      if node.isGap {
        items[0].append(node)
      } else if let mediaStatus = node.mediaStatus {
        let targetColIndex: Int

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

  public var body: some View {
    let isSquare = UserPreferences.shared.galleryCropToSquare
    let isIceShrimp = mediaStatus.status.account.url?.absoluteString.lowercased().contains("iceshrimp") == true
    let fallback = UserPreferences.shared.remoteMediaFallbackOnFail || (UserPreferences.shared.useIceShrimpWorkarounds && isIceShrimp)
    let effectiveUseRemoteMedia = isRemote || UserPreferences.shared.remoteMediaAlwaysForce
    let resolvedUrl = effectiveUseRemoteMedia ? (mediaStatus.attachment.remoteUrl ?? mediaStatus.attachment.url) : mediaStatus.attachment.url
    let fallbackUrl: URL? = {
      if fallback {
        let candidateFallback = effectiveUseRemoteMedia ? mediaStatus.attachment.url : mediaStatus.attachment.remoteUrl
        return candidateFallback == resolvedUrl ? nil : candidateFallback
      } else {
        return nil
      }
    }()
    if let url = resolvedUrl {
      Button {
        if let viewModel {
          viewModel.navigateToDetail()
        } else {
          routerPath.navigate(to: .statusDetailWithStatus(status: mediaStatus.status))
        }
      } label: {
        Group {
          switch mediaStatus.attachment.supportedType {
          case .image:
            LazyImage(url: url, transaction: Transaction(animation: .easeIn)) { state in
              if let image = state.image {
                if mediaStatus.attachment.aspectRatio == nil && !isSquare {
                  image
                    .resizable()
                    .scaledToFit()
                } else {
                  image
                    .resizable()
                    .scaledToFill()
                }
              } else {
                ZStack {
                  Color.secondary.opacity(0.1)
                  ProgressView()
                }
                .aspectRatio(mediaStatus.attachment.meta?.original == nil ? 1 : nil, contentMode: .fit)
              }
            }
            .transition(.opacity)
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

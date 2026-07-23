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
      // Provide stable fake heights so the placeholders don't jitter on re-evaluation
      let isSquare = UserPreferences.shared.galleryCropToSquare
      let placeholderRatios: [CGFloat] = isSquare ? [1.0] : [1.0, 1.5, 0.8, 1.2, 0.9, 1.3]
      HStack(alignment: .top, spacing: 4) {
        ForEach(0..<columns, id: \.self) { colIndex in
          LazyVStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { rowIndex in
              RoundedRectangle(cornerRadius: 8)
                .fill(theme.secondaryBackgroundColor)
                .aspectRatio(placeholderRatios[(colIndex + rowIndex) % placeholderRatios.count], contentMode: .fit)
                .padding(.bottom, 4)
            }
            Spacer(minLength: 0)
          }
          .frame(minWidth: 0, maxWidth: .infinity)
        }
      }
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
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
    
    VStack(spacing: 0) {
      ForEach(chunks) { chunk in
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
    }
    .task(id: items.count) {
      let mediaCount = items.filter { if case .status(let status) = $0 { return !status.asMediaStatus.isEmpty }; return false }.count
      if mediaCount < 6 && nextPageState == .hasNextPage {
        try? await fetcher.fetchNextPage()
      }
    }
    
    makeNextPageRow(nextPageState: nextPageState)
  }

  @ViewBuilder
  private func makeGridChunk(for items: [TimelineItem]) -> some View {
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
    
    let columns = UserPreferences.shared.galleryColumns
    
    let columnItems: [[GalleryNode]] = {
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
          var aspectRatio = isSquare ? 1.0 : (mediaStatus.attachment.clampedAspectRatio ?? 1.0)
          if aspectRatio <= 0 { aspectRatio = 1.0 }
          columnHeights[targetColIndex] += (1.0 / aspectRatio) + 0.1
          currentIndex += 1
        } else {
          // Trailing anchors with no media
          items[0].append(node)
        }
      }
      
      return items
    }()
    
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
          Spacer(minLength: 0)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
      }
    }
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

  public var body: some View {
    let isSquare = UserPreferences.shared.galleryCropToSquare
    if let url = mediaStatus.attachment.url {
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
                image
                  .resizable()
                  .scaledToFill()
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
            MediaUIAttachmentVideoView(viewModel: .init(url: url))
              .allowsHitTesting(false)
          default:
            EmptyView()
          }
        }
        .modifier(GalleryAspectRatioModifier(isSquare: isSquare, aspectRatio: mediaStatus.attachment.clampedAspectRatio))
        .clipped()
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
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
        .scaledToFit()
        .clipped()
    }
  }
}

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
          LazyVStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { rowIndex in
              RoundedRectangle(cornerRadius: 8)
                .fill(theme.secondaryBackgroundColor)
                .aspectRatio(placeholderRatios[(colIndex + rowIndex) % placeholderRatios.count], contentMode: .fit)
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

  private enum GalleryItem: Identifiable, Equatable {
    case media(MediaStatus)
    case gap(TimelineGap)

    var id: String {
      switch self {
      case .media(let media): return media.id
      case .gap(let gap): return gap.id
      }
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
    let galleryItems: [GalleryItem] = items.flatMap { item -> [GalleryItem] in
      switch item {
      case .status(let status):
        return status.asMediaStatus.map { .media($0) }
      case .gap(let gap):
        return [.gap(gap)]
      }
    }
    
    let columns = UserPreferences.shared.galleryColumns
    
    // Distribute items into columns to optimize layout.
    // We calculate the masonry layout from the BOTTOM UP (oldest to newest).
    // This ensures that when newer posts are loaded at the top, the existing posts
    // retain their column assignments, preventing the entire grid from reshuffling
    // and destroying the user's scroll position.
    let columnItems: [[GalleryItem]] = {
      var items: [[GalleryItem]] = Array(repeating: [], count: columns)
      var columnHeights: [CGFloat] = Array(repeating: 0, count: columns)
      
      for item in galleryItems.reversed() {
        if case .gap = item {
          items[0].append(item)
        } else if case .media(let mediaStatus) = item {
          // Find shortest column
          var shortestColIndex = 0
          var shortestHeight = columnHeights[0]
          
          for i in 1..<columns {
            if columnHeights[i] < shortestHeight {
              shortestHeight = columnHeights[i]
              shortestColIndex = i
            }
          }
          
          items[shortestColIndex].append(item)
          
          // Estimate height of this item based on its aspect ratio to distribute evenly
          let isSquare = UserPreferences.shared.galleryCropToSquare
          let aspectRatio = isSquare ? 1.0 : (mediaStatus.attachment.clampedAspectRatio ?? 1.0)
          
          // The relative height is proportional to 1.0 / aspectRatio
          // Add a small constant to account for padding
          columnHeights[shortestColIndex] += (1.0 / aspectRatio) + 0.1
        }
      }
      
      // Reverse each column's items so they are ordered newest to oldest (top to bottom)
      for i in 0..<columns {
        items[i].reverse()
      }
      
      return items
    }()
    
    let mediaCount = galleryItems.filter { if case .media = $0 { return true }; return false }.count
    
    HStack(alignment: .top, spacing: 4) {
      ForEach(0..<columns, id: \.self) { colIndex in
        LazyVStack(spacing: 4) {
          ForEach(columnItems[colIndex]) { item in
            switch item {
            case .media(let mediaStatus):
              GalleryMediaCell(
                mediaStatus: mediaStatus,
                routerPath: routerPath,
                client: client,
                isRemote: isRemote,
                filterContext: filterContext
              )
              .id(mediaStatus.status.id)
              .onAppear { fetcher.statusDidAppear(status: mediaStatus.status) }
              .onDisappear { fetcher.statusDidDisappear(status: mediaStatus.status) }
            case .gap(let gap):
              if let gapLoader = fetcher as? GapLoadingFetcher {
                TimelineGapView(gap: gap) {
                  await gapLoader.loadGap(gap: gap)
                }
                .padding(.horizontal, .layoutPadding)
                .padding(.vertical, 8)
              }
            }
          }
          Spacer(minLength: 0)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
      }
    }
    .task(id: items.count) {
      if mediaCount < 6 && nextPageState == .hasNextPage {
        try? await fetcher.fetchNextPage()
      }
    }
    
    makeNextPageRow(nextPageState: nextPageState)
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

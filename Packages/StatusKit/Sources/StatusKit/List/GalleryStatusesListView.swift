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
      let placeholderRatios: [CGFloat] = [1.0, 1.5, 0.8, 1.2, 0.9, 1.3]
      HStack(alignment: .top, spacing: 4) {
        ForEach(0..<columns, id: \.self) { colIndex in
          VStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { rowIndex in
              RoundedRectangle(cornerRadius: 8)
                .fill(theme.secondaryBackgroundColor)
                .aspectRatio(placeholderRatios[(colIndex + rowIndex) % placeholderRatios.count], contentMode: .fit)
            }
          }
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
      makeGrid(for: statuses, nextPageState: nextPageState)
    case .displayWithGaps(let items, let nextPageState):
      let segments = makeSegments(from: items)
      ForEach(segments) { segment in
        switch segment {
        case .grid(_, let segmentStatuses):
          makeGrid(for: segmentStatuses, nextPageState: segment.id == segments.last?.id ? nextPageState : .none)
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
    }
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
  private func makeGrid(for statuses: [Status], nextPageState: StatusesState.PagingState) -> some View {
    let mediaStatuses = statuses.flatMap { $0.asMediaStatus }
    let columns = UserPreferences.shared.galleryColumns
    
    // Distribute items into columns round-robin
    let columnItems: [[MediaStatus]] = {
      var items: [[MediaStatus]] = Array(repeating: [], count: columns)
      for (index, status) in mediaStatuses.enumerated() {
          items[index % columns].append(status)
      }
      return items
    }()
    
    HStack(alignment: .top, spacing: 4) {
      ForEach(0..<columns, id: \.self) { colIndex in
        VStack(spacing: 4) {
          ForEach(columnItems[colIndex]) { status in
            GalleryMediaCell(
              mediaStatus: status,
              routerPath: routerPath,
              client: client,
              isRemote: isRemote,
              filterContext: filterContext
            )
              .id(status.status.id)
              .onAppear { fetcher.statusDidAppear(status: status.status) }
              .onDisappear { fetcher.statusDidDisappear(status: status.status) }
          }
          Spacer(minLength: 0)
        }
      }
    }
    .task(id: statuses.count) {
      if mediaStatuses.count < 6 && nextPageState == .hasNextPage {
        // The cache-write lockup was resolved in TimelineViewModel.
        // We can now auto-fetch empty pages as fast as the network allows without artificial sleeping.
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
        .modifier(GalleryAspectRatioModifier(isSquare: isSquare, meta: mediaStatus.attachment.meta?.original))
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
    public let meta: MediaAttachment.MetaContainer.Meta?
    
    public init(isSquare: Bool, meta: MediaAttachment.MetaContainer.Meta?) {
      self.isSquare = isSquare
      self.meta = meta
    }
    
    public func body(content: Content) -> some View {
        if isSquare {
            content.aspectRatio(1, contentMode: .fill)
        } else if let meta = meta, let width = meta.width, let height = meta.height, width > 0, height > 0 {
            content
                .aspectRatio(CGFloat(width) / CGFloat(height), contentMode: .fit)
                .frame(maxHeight: 400)
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

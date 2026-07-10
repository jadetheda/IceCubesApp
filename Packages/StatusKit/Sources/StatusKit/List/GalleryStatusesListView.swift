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
      makeGrid(for: statuses, nextPageState: nextPageState)
    case .displayWithGaps(let items, let nextPageState):
      let statuses = items.compactMap { item -> Status? in
          if case let .status(status) = item { return status }
          return nil
      }
      makeGrid(for: statuses, nextPageState: nextPageState)
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
        LazyVStack(spacing: 4) {
          ForEach(columnItems[colIndex]) { status in
            GalleryMediaCell(
              mediaStatus: status,
              routerPath: routerPath,
              client: client,
              isRemote: isRemote,
              filterContext: filterContext
            )
              .onAppear { fetcher.statusDidAppear(status: status.status) }
              .onDisappear { fetcher.statusDidDisappear(status: status.status) }
          }
        }
      }
    }
    .padding(.horizontal, 4)
    .task(id: statuses.count) {
      if mediaStatuses.count < 6 && nextPageState == .hasNextPage {
        try? await fetcher.fetchNextPage()
      }
    }
    
    makeNextPageRow(nextPageState: nextPageState)
  }
}

@MainActor
struct GalleryMediaCell: View {
  let mediaStatus: MediaStatus
  let routerPath: RouterPath
  let client: MastodonClient
  let isRemote: Bool
  let filterContext: Filter.Context?

  @State private var viewModel: StatusRowViewModel?
  @State private var showSelectableText: Bool = false
  @State private var isBlockConfirmationPresented = false
  @State private var isShareAsImageSheetPresented = false

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
            .allowsHitTesting(false)
        default:
          EmptyView()
        }
      }
      .modifier(GalleryAspectRatioModifier(isSquare: isSquare, meta: mediaStatus.attachment.meta?.original))
      .clipped()
      .contentShape(Rectangle())
      .onTapGesture {
        if let viewModel {
          viewModel.navigateToDetail()
        } else {
          routerPath.navigate(to: .statusDetailWithStatus(status: mediaStatus.status))
        }
      }
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

struct GalleryAspectRatioModifier: ViewModifier {
    let isSquare: Bool
    let meta: MediaAttachment.MetaContainer.Meta?
    
    func body(content: Content) -> some View {
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

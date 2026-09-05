import DesignSystem
import Env
import Models
import NetworkClient
import MediaUI
import NukeUI
import SwiftUI

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

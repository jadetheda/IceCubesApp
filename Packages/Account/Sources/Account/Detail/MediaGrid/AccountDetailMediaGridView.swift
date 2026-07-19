import DesignSystem
import Env
import MediaUI
import Models
import NetworkClient
import NukeUI
import SwiftUI

@MainActor
public struct AccountDetailMediaGridView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(MastodonClient.self) private var client
  @Environment(QuickLook.self) private var quickLook
  // Read user preferences so remote media settings (alwaysForce, fallbackOnFail)
  // work in the profile gallery — the same way they work in the timeline.
  @Environment(UserPreferences.self) private var userPreferences

  let account: Account
  @State var mediaStatuses: [MediaStatus]
  // Tracks whether the auto-fallback timer has fired for the whole grid.
  // Individual cell failures are handled per-cell via LazyImage's phase.
  @State private var autoFallbackTriggered: Bool = false
  @State private var fallbackTask: Task<Void, Never>?
  @State private var loadedCount: Int = 0

  public init(account: Account, initialMediaStatuses: [MediaStatus]) {
    self.account = account
    mediaStatuses = initialMediaStatuses
  }

  // Mirrors StatusRowMediaPreviewView.effectiveUseRemoteMedia.
  private var effectiveUseRemoteMedia: Bool {
    autoFallbackTriggered || userPreferences.remoteMediaAlwaysForce
  }

  public var body: some View {
    ScrollView(.vertical) {
      LazyVGrid(
        columns: [
          .init(.flexible(minimum: 100), spacing: 4),
          .init(.flexible(minimum: 100), spacing: 4),
          .init(.flexible(minimum: 100), spacing: 4),
        ],
        spacing: 4
      ) {
        ForEach(mediaStatuses) { status in
          GeometryReader { proxy in
            // Resolve the URL using the same priority logic as StatusRowMediaPreviewView:
            // prefer remoteUrl when force-remote is on, otherwise use local url.
            let resolvedURL = effectiveUseRemoteMedia
              ? (status.attachment.remoteUrl ?? status.attachment.url)
              : status.attachment.url
            // Fallback URL used when the primary load fails (mirrors DisplayData logic).
            let fallbackURL: URL? = userPreferences.remoteMediaFallbackOnFail
              ? (status.attachment.remoteUrl ?? status.attachment.url)
              : status.attachment.url

            if let url = resolvedURL {
              Group {
                switch status.attachment.supportedType {
                case .image:
                  LazyImage(url: url, transaction: Transaction(animation: .easeIn)) { state in
                    if let image = state.image {
                      image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.width)
                    } else if state.error != nil, let fallback = fallbackURL, fallback != url {
                      // Primary URL failed to load — try the fallback (remote) URL.
                      LazyImage(url: fallback) { fallbackState in
                        if let img = fallbackState.image {
                          img
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.width)
                        } else {
                          ProgressView()
                            .frame(width: proxy.size.width, height: proxy.size.width)
                        }
                      }
                    } else {
                      ProgressView()
                        .frame(width: proxy.size.width, height: proxy.size.width)
                    }
                  }
                  .onSuccess { _ in
                    loadedCount += 1
                  }
                  .processors([.resize(size: proxy.size)])
                  .transition(.opacity)
                case .gifv, .video:
                  MediaUIAttachmentVideoView(
                    viewModel: .init(
                      url: url,
                      // Pass the fallback URL so video also benefits from fallback-on-fail.
                      fallbackUrl: fallbackURL
                    )
                  )
                case .none:
                  EmptyView()
                case .some(.audio):
                  EmptyView()
                }
              }
              .onTapGesture {
                routerPath.navigate(to: .statusDetailWithStatus(status: status.status))
              }
              .contextMenu {
                Button {
                  quickLook.prepareFor(
                    selectedMediaAttachment: status.attachment,
                    mediaAttachments: status.status.mediaAttachments)
                } label: {
                  Label("Open Media", systemImage: "photo")
                }
                MediaUIShareLink(
                  url: url, type: status.attachment.supportedType == .image ? .image : .av)
                Button {
                  Task {
                    let transferable = MediaUIImageTransferable(url: url)
                    UIPasteboard.general.image = UIImage(data: await transferable.fetchData())
                  }
                } label: {
                  Label("status.media.contextmenu.copy", systemImage: "doc.on.doc")
                }
                Button {
                  UIPasteboard.general.url = url
                } label: {
                  Label("status.action.copy-link", systemImage: "link")
                }
              }
            }
          }
          .clipped()
          .aspectRatio(1, contentMode: .fit)
        }

        VStack {
          Spacer()
          NextPageView {
            try await fetchNextPage()
          }
          Spacer()
        }
      }
    }
    .navigationTitle(account.displayName ?? "")
    .onAppear {
      // Start auto-fallback timer if the preference is enabled, mirroring
      // StatusRowMediaPreviewView.onAppear. If images haven't loaded within
      // the configured delay, flip effectiveUseRemoteMedia to true.
      if userPreferences.remoteMediaAutoFallback && !effectiveUseRemoteMedia {
        fallbackTask = Task {
          try? await Task.sleep(
            nanoseconds: UInt64(userPreferences.remoteMediaAutoFallbackDelay * 1_000_000_000.0))
          if !Task.isCancelled && loadedCount < mediaStatuses.count {
            autoFallbackTriggered = true
          }
        }
      }
    }
    .onDisappear {
      fallbackTask?.cancel()
    }
    .onChange(of: loadedCount) { _, newValue in
      // Cancel the fallback timer once all visible images have loaded.
      if newValue >= mediaStatuses.count {
        fallbackTask?.cancel()
      }
    }
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.primaryBackgroundColor)
    #endif
  }

  private func fetchNextPage() async throws {
    let newStatuses: [Status] =
      try await client.get(
        endpoint: Accounts.statuses(
          id: account.id,
          sinceId: mediaStatuses.last?.id,
          tag: nil,
          onlyMedia: true,
          excludeReplies: true,
          excludeReblogs: true,
          pinned: nil))
    mediaStatuses.append(contentsOf: newStatuses.flatMap { $0.asMediaStatus })
  }
}

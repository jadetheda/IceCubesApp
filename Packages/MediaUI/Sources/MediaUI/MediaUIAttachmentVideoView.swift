import AVKit
import DesignSystem
import Env
import Models
import Observation
import SwiftUI

@MainActor
@Observable public class MediaUIAttachmentVideoViewModel {
  var player: AVPlayer?
  private var observer: NSKeyValueObservation?
  let url: URL
  let fallbackUrl: URL?
  let forceAutoPlay: Bool
  var isPlaying: Bool = false
  var loopVideo: Bool = false
  @ObservationIgnored private var playbackEndObserver: NSObjectProtocol?
  public var onReady: (() -> Void)?
  public var hasFalledBack = false
  public var isDead = false

  public init(url: URL, fallbackUrl: URL? = nil, forceAutoPlay: Bool = false, onReady: (() -> Void)? = nil) {
    self.onReady = onReady
    self.url = url
    self.fallbackUrl = fallbackUrl
    self.forceAutoPlay = forceAutoPlay
  }

  private func makeAsset(for targetUrl: URL) -> AVURLAsset {
    let ext = targetUrl.pathExtension.lowercased()
    if ext.isEmpty || ext == "gif" {
      return AVURLAsset(url: targetUrl, options: ["AVURLAssetOutOfBandMIMETypeKey": "video/mp4"])
    }
    return AVURLAsset(url: targetUrl)
  }

  private func registerLoopObserver(for item: AVPlayerItem?) {
    if let playbackEndObserver {
      NotificationCenter.default.removeObserver(playbackEndObserver)
      self.playbackEndObserver = nil
    }
    guard let item else { return }
    playbackEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        if self.loopVideo {
          self.play()
        }
      }
    }
  }

  func preparePlayer(autoPlay: Bool, isCompact: Bool, loopVideo: Bool) {
    let activeUrl = (hasFalledBack && fallbackUrl != nil) ? fallbackUrl! : url
    let asset = makeAsset(for: activeUrl)
    let item = AVPlayerItem(asset: asset)
    player = .init(playerItem: item)
    player?.audiovisualBackgroundPlaybackPolicy = .pauses
    #if !os(visionOS)
      player?.preventsDisplaySleepDuringVideoPlayback = false
    #endif
    let shouldPlay = autoPlay || forceAutoPlay
    if shouldPlay {
      if !isCompact {
        player?.play()
        isPlaying = true
      } else {
        player?.pause()
        isPlaying = false
      }
    } else {
      player?.pause()
      isPlaying = false
    }

    self.loopVideo = loopVideo
    setupObserver(for: item)
    registerLoopObserver(for: item)
  }

  func mute(_ mute: Bool) {
    player?.isMuted = mute
  }

  func pause() {
    isPlaying = false
    player?.pause()
  }

  func stop() {
    isPlaying = false
    player?.pause()
    player = nil
  }

  func play() {
    isPlaying = true
    player?.seek(to: CMTime.zero)
    player?.play()
  }

  func resume() {
    isPlaying = true
    player?.play()
  }

  func preventSleep(_ preventSleep: Bool) {
    #if !os(visionOS)
      player?.preventsDisplaySleepDuringVideoPlayback = preventSleep
    #endif
  }

  private func setupObserver(for item: AVPlayerItem?) {
    observer = item?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
      if item.status == .failed {
        Task { @MainActor [weak self] in
          guard let self else { return }
          if let fallbackUrl = self.fallbackUrl, !self.hasFalledBack {
            self.hasFalledBack = true
            let wasPlaying = self.isPlaying
            let fallbackAsset = self.makeAsset(for: fallbackUrl)
            let newItem = AVPlayerItem(asset: fallbackAsset)
            self.player?.replaceCurrentItem(with: newItem)
            self.setupObserver(for: newItem)
            self.registerLoopObserver(for: newItem)
            if wasPlaying {
              self.player?.play()
            }
          } else {
            self.isDead = true
            ErrorService.shared.handle(
              title: "Video Load Error",
              message: "Failed to load video: \(item.error?.localizedDescription ?? "Unknown error"). URL: \(self.url.absoluteString)",
              showPopup: false,
              log: true
            )
          }
        }
      } else if item.status == .readyToPlay {
        Task { @MainActor [weak self] in
          self?.onReady?()
        }
      }
    }
  }

  isolated deinit {
    if let playbackEndObserver {
      NotificationCenter.default.removeObserver(playbackEndObserver)
    }
  }
}

@MainActor
public struct MediaUIAttachmentVideoView: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.isCatalystWindow) private var isCatalystWindow
  @Environment(\.isMediaCompact) private var isCompact
  @Environment(UserPreferences.self) private var preferences
  @Environment(Theme.self) private var theme

  @State var viewModel: MediaUIAttachmentVideoViewModel
  @State var isFullScreen: Bool = false

  public init(viewModel: MediaUIAttachmentVideoViewModel) {
    _viewModel = .init(wrappedValue: viewModel)
  }

  private var shouldAutoPlayOnAppear: Bool {
    isFullScreen ? true : preferences.autoPlayVideo
  }

  private var shouldResumeOnActive: Bool {
    if isCompact { return false }
    if preferences.autoPlayVideo { return true }
    if viewModel.forceAutoPlay { return true }
    if isFullScreen { return true }
    return false
  }

  private var shouldShowManualPlayButton: Bool {
    if preferences.autoPlayVideo { return false }
    if viewModel.forceAutoPlay { return false }
    if isFullScreen { return false }
    if viewModel.isPlaying { return false }
    if isCompact { return false }
    return true
  }

  private var playerViewId: String {
    "\(viewModel.url.absoluteString)-\(viewModel.hasFalledBack)-\(viewModel.player != nil)"
  }

  public var body: some View {
    videoView
      .overlay(content: {
        if isCatalystWindow {
          EmptyView()
        } else {
          HStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
              if !preferences.autoPlayVideo {
                if !viewModel.isPlaying {
                  viewModel.play()
                  return
                }
              }
              #if targetEnvironment(macCatalyst)
                viewModel.pause()
                let attachement = MediaAttachment.videoWith(url: viewModel.url)
                openWindow(
                  value: WindowDestinationMedia.mediaViewer(
                    attachments: [attachement], selectedAttachment: attachement, useRemoteMedia: false, exportMetadata: nil))
              #else
                isFullScreen = true
              #endif
            }
        }
      })
      .onAppear {
        viewModel.preparePlayer(
          autoPlay: shouldAutoPlayOnAppear,
          isCompact: isCompact,
          loopVideo: preferences.loopVideo)
        viewModel.mute(preferences.muteVideo)
      }
      .onDisappear {
        viewModel.stop()
      }
      .fullScreenCover(isPresented: $isFullScreen) {
        modalPreview
      }
      .cornerRadius(4)
      .onChange(of: scenePhase) { _, newValue in
        switch newValue {
        case .background, .inactive:
          viewModel.pause()
        case .active:
          if shouldResumeOnActive {
            viewModel.play()
          }
        default:
          break
        }
      }
  }

  private var modalPreview: some View {
    NavigationStack {
      videoView
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              isFullScreen.toggle()
            } label: {
              Image(systemName: "xmark.circle")
            }
          }
          QuickLookToolbarItem(itemUrl: viewModel.url)
        }
    }
    .onAppear {
      DispatchQueue.global().async {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
      }
      viewModel.preventSleep(true)
      viewModel.mute(false)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        if isCompact || !preferences.autoPlayVideo {
          viewModel.play()
        } else {
          viewModel.resume()
        }
      }
    }
    .onDisappear {
      if isCompact || !preferences.autoPlayVideo {
        viewModel.pause()
      }
      viewModel.preventSleep(false)
      viewModel.mute(preferences.muteVideo)
      DispatchQueue.global().async {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
      }
    }
  }

  private var playButtonFont: Font {
    isCompact ? .body : .largeTitle
  }

  private var playButtonPadding: CGFloat? {
    isCompact ? 6 : nil
  }

  private var playButtonOuterPadding: CGFloat {
    theme.statusDisplayStyle == .compact ? 0 : 10
  }

  private var videoView: some View {
    VideoPlayer(
      player: viewModel.player,
      videoOverlay: {
        if viewModel.isDead {
          ZStack {
            Color.black.opacity(0.5)
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.largeTitle)
              .foregroundColor(.white)
          }
        } else if shouldShowManualPlayButton {
          Button(
            action: {
              viewModel.play()
            },
            label: {
              Image(systemName: "play.fill")
                .font(playButtonFont)
                .foregroundColor(theme.tintColor)
                .padding(.all, playButtonPadding)
                .background(Circle().fill(.thinMaterial))
                .padding(playButtonOuterPadding)
            })
        }
      }
    )
    .accessibilityAddTraits(.startsMediaSession)
    // On iOS 17/18, when VideoPlayer initializes with a nil AVPlayer (while the asset is
    // loading), updating the state to a non-nil AVPlayer frequently fails to trigger a redraw.
    // The `.id()` modifier forces SwiftUI's diffing engine to recreate the underlying
    // AVPlayerViewController when the player instance or fallback URL changes.
    .id(playerViewId)
  }
}

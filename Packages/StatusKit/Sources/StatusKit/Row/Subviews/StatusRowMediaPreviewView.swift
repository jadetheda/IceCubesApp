import DesignSystem
import Env
import MediaUI
import Models
import Nuke
import NukeUI
import SwiftUI

@MainActor
public struct StatusRowMediaPreviewView: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.isMediaCompact) private var isCompact: Bool
  @Environment(QuickLook.self) private var quickLook
  @Environment(Theme.self) private var theme
  @Environment(UserPreferences.self) private var userPreferences
  @State private var autoFallbackTriggered: Bool = false
  @State private var loadedAttachments: Set<String> = []
  @State private var loadTask: Task<Void, Never>?

  private var effectiveUseRemoteMedia: Bool {
    useRemoteMedia || autoFallbackTriggered || userPreferences.remoteMediaAlwaysForce || (userPreferences.useIceShrimpWorkarounds && CurrentInstance.shared.isIceShrimp)
  }

  public let attachments: [MediaAttachment]
  public let sensitive: Bool
  public let useRemoteMedia: Bool

  @State private var isQuickLookLoading: Bool = false

  public init(attachments: [MediaAttachment], sensitive: Bool, useRemoteMedia: Bool = false) {
    self.attachments = attachments
    self.sensitive = sensitive
    self.useRemoteMedia = useRemoteMedia
  }

  #if targetEnvironment(macCatalyst)
    private var showsScrollIndicators: Bool { attachments.count > 1 }
    private var scrollBottomPadding: CGFloat?
  #else
    private var showsScrollIndicators: Bool = false
    private var scrollBottomPadding: CGFloat? = 0
  #endif

  private var imageMaxHeight: CGFloat {
    if isCompact {
      return 50
    }
    if theme.statusDisplayStyle == .compact {
      if attachments.count == 1 {
        return 200
      }
      return 100
    }
    return 300
  }

  public var body: some View {
    Group {
      if attachments.count == 1 {
        if userPreferences.cropStatusMediaOnTimeline {
          FeaturedImagePreView(
            attachment: attachments[0],
            useRemoteMedia: effectiveUseRemoteMedia,
            maxSize: imageMaxHeight == 300
              ? nil
              : CGSize(width: imageMaxHeight, height: imageMaxHeight),
            sensitive: sensitive,
            onLoaded: { loadedAttachments.insert(attachments[0].id) }
          )
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Self.accessibilityLabel(for: attachments[0]))
          .accessibilityAddTraits([.isButton, .isImage])
          .onTapGesture { tabAction(for: 0) }
        } else {
          StatusRowMediaGridView(
            attachments: attachments,
            sensitive: sensitive,
            imageMaxHeight: imageMaxHeight,
            useRemoteMedia: effectiveUseRemoteMedia,
            userPreferences: userPreferences,
            onLoaded: { id in loadedAttachments.insert(id) },
            tabAction: { index in tabAction(for: index) }
          )
        }
      } else if userPreferences.statusMediaGridMode && attachments.count <= 4 {
        StatusRowMediaGridView(
          attachments: attachments,
          sensitive: sensitive,
          imageMaxHeight: imageMaxHeight,
          useRemoteMedia: effectiveUseRemoteMedia,
          userPreferences: userPreferences,
          onLoaded: { id in loadedAttachments.insert(id) },
          tabAction: { index in tabAction(for: index) }
        )
      } else {
        ScrollView(.horizontal, showsIndicators: showsScrollIndicators) {
          HStack {
            ForEach(attachments) { attachment in
              makeAttachmentView(attachment)
            }
          }
          .padding(.bottom, scrollBottomPadding)
        }
        .scrollClipDisabled()
      }
    }
    .onAppear {
      if userPreferences.remoteMediaAutoFallback && !effectiveUseRemoteMedia {
        loadTask = Task {
          try? await Task.sleep(nanoseconds: UInt64(userPreferences.remoteMediaAutoFallbackDelay * 1_000_000_000.0))
          if !Task.isCancelled {
            if loadedAttachments.count < attachments.count {
              autoFallbackTriggered = true
            }
          }
        }
      }
    }
    .onDisappear {
      loadTask?.cancel()
    }
    .onChange(of: loadedAttachments) { _, newValue in
      if newValue.count == attachments.count {
        loadTask?.cancel()
      }
    }

  }

  @ViewBuilder
  private func makeAttachmentView(_ attachement: MediaAttachment) -> some View {
    let isIceShrimp = CurrentInstance.shared.isIceShrimp
    let fallback = userPreferences.remoteMediaFallbackOnFail || (userPreferences.useIceShrimpWorkarounds && isIceShrimp)
    let noVideo = userPreferences.neverLoadVideo

    if let data = DisplayData(from: attachement, useRemoteMedia: effectiveUseRemoteMedia, fallbackOnFail: fallback, neverLoadVideo: noVideo) {
      MediaPreview(
        sensitive: sensitive,
        imageMaxHeight: imageMaxHeight,
        displayData: data,
        isStandalone: attachments.count == 1,
        onLoaded: { loadedAttachments.insert(attachement.id) }
      )
      .id(data.url)
      .onTapGesture {
        if let index = attachments.firstIndex(where: { $0.id == attachement.id }) {
          tabAction(for: index)
        }
      }
      #if os(visionOS)
        .hoverEffect()
      #endif
    }
  }

  private func tabAction(for index: Int) {
    #if targetEnvironment(macCatalyst) || os(visionOS)
      openWindow(
        value: WindowDestinationMedia.mediaViewer(
          attachments: attachments,
          selectedAttachment: attachments[index]
        )
      )
    #else
      quickLook.prepareFor(
        selectedMediaAttachment: attachments[index],
        mediaAttachments: attachments
      )
    #endif
  }

  private static func accessibilityLabel(for attachment: MediaAttachment) -> Text {
    if let altText = attachment.description {
      Text("accessibility.image.alt-text-\(altText)")
    } else if let typeDescription = attachment.localizedTypeDescription {
      Text(typeDescription)
    } else {
      Text("accessibility.tabs.profile.picker.media")
    }
  }
}

private struct MediaPreview: View {
  @Environment(QuickLook.self) private var quickLook
  
  let sensitive: Bool
  let imageMaxHeight: CGFloat
  let displayData: DisplayData
  var isStandalone: Bool = false
  var onLoaded: () -> Void = {}

  @State private var loadedAspectRatio: CGFloat? = nil

  private var currentAspectRatio: CGFloat? {
    return displayData.standaloneAspectRatio ?? loadedAspectRatio ?? 1.0
  }

  var body: some View {
    if let namespace = quickLook.namespace {
      Group {
        switch displayData.type {
        case .image:
          LazyResizableImage(url: displayData.previewUrl, fallbackUrl: displayData.fallbackUrl) { state in
            if let image = state.image {
              image
                .resizable()
                .onAppear {
                  onLoaded()
                  if displayData.standaloneAspectRatio == nil, loadedAspectRatio == nil, let size = state.imageContainer?.image.size, size.height > 0 {
                    let ratio = size.width / size.height
                    DispatchQueue.main.async {
                      loadedAspectRatio = min(max(ratio, 0.25), 4.0)
                    }
                  }
                }
                .aspectRatio(contentMode: .fill)
                .frame(
                  maxWidth: isStandalone ? .infinity : nil,
                  maxHeight: isStandalone ? (imageMaxHeight * 2.5) : nil
                )
                .frame(
                  width: isStandalone ? nil : (displayData.isLandscape ? imageMaxHeight * 1.2 : imageMaxHeight / 1.5),
                  height: isStandalone ? nil : imageMaxHeight
                )
            } else if state.isLoading {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(.gray.opacity(0.35), lineWidth: 1)
          )
          .overlay {
            BlurOverLay(sensitive: sensitive, font: .scaledFootnote)
          }
          .overlay {
            AltTextButton(text: displayData.description, font: .scaledFootnote)
          }
        case .av:
          MediaUIAttachmentVideoView(viewModel: .init(url: displayData.url, fallbackUrl: displayData.fallbackUrl, onReady: { onLoaded() }))
            .accessibilityAddTraits(.startsMediaSession)
        }
      }
      .matchedTransitionSource(id: displayData.id, in: namespace)
      .aspectRatio(isStandalone ? currentAspectRatio : nil, contentMode: .fit)
      .frame(
        maxWidth: isStandalone ? .infinity : nil,
        maxHeight: isStandalone ? (imageMaxHeight * 2.5) : nil
      )
      .frame(
        width: isStandalone ? nil : (displayData.isLandscape ? imageMaxHeight * 1.2 : imageMaxHeight / 1.5),
        height: isStandalone ? nil : imageMaxHeight
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
      // #965: do not create overlapping tappable areas, when multiple images are shown
      .contentShape(Rectangle())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(displayData.accessibilityText))
      .accessibilityAddTraits(displayData.type == .image ? [.isImage, .isButton] : .isButton)
    }
  }
}

@MainActor
struct BlurOverLay: View {
  let sensitive: Bool
  let font: Font?

  @State private var isFrameExpanded = true

  @Environment(Theme.self) private var theme
  @Environment(\.isInCaptureMode) private var isInCaptureMode: Bool
  @Environment(UserPreferences.self) private var preferences
  @Environment(\.isMediaCompact) private var isCompact: Bool

  @Namespace var buttonSpace

  var body: some View {
    if hasOverlay {
      ZStack {
        Rectangle()
          .foregroundColor(.clear)
          .background(.ultraThinMaterial)
          .frame(
            width: isFrameExpanded ? nil : 0,
            height: isFrameExpanded ? nil : 0
          )
        if !isCompact {
          Button {
            withAnimation(.spring) {
              isFrameExpanded.toggle()
            }
          } label: {
            if isFrameExpanded {
              ViewThatFits(in: .horizontal) {
                HStack {
                  Image(systemName: "eye")
                    .matchedGeometryEffect(id: "eye", in: buttonSpace)
                  Text(sensitive ? "status.media.sensitive.show" : "status.media.content.show")
                }
                HStack {
                  Image(systemName: "eye")
                    .matchedGeometryEffect(id: "eye", in: buttonSpace)
                  Text("Show")
                }
                Image(systemName: "eye")
                  .matchedGeometryEffect(id: "eye", in: buttonSpace)
              }
              .lineLimit(1)
              .foregroundColor(theme.contrastingTintColor)
            } else {
              Image(systemName: "eye.slash")
                .transition(.opacity)
                .matchedGeometryEffect(id: "eye", in: buttonSpace)
            }
          }
          .foregroundColor(theme.labelColor)
          .buttonStyle(.borderedProminent)
          .padding(theme.statusDisplayStyle == .compact ? 0 : 10)
        }
      }
      .font(font)
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: isFrameExpanded ? .center : .bottomLeading
      )
    } else {
      EmptyView()
    }
  }

  private var hasOverlay: Bool {
    switch (sensitive, preferences.autoExpandMedia) {
    case (_, .hideAll), (true, .hideSensitive):
      switch isInCaptureMode {
      case true: false
      case false: true
      }
    default: false
    }
  }
}

struct AltTextButton: View {
  let text: String?
  let font: Font?

  @Environment(\.isInCaptureMode) private var isInCaptureMode: Bool
  @Environment(\.isMediaCompact) private var isCompact: Bool
  @Environment(UserPreferences.self) private var preferences
  @Environment(\.locale) private var locale
  @Environment(Theme.self) private var theme

  @State private var isDisplayingAlert = false
  @State private var isDisplayingTranslation = false

  var body: some View {
    if !isInCaptureMode,
      let text,
      !text.isEmpty,
      !isCompact,
      preferences.showAltTextForMedia
    {
      Button {
        isDisplayingAlert = true
      } label: {
        ZStack {
          // use to sync button with show/hide content button
          Image(systemName: "eye.slash").opacity(0)
          Text("status.image.alt-text.abbreviation")
        }
      }
      .buttonStyle(.borderless)
      .padding(EdgeInsets(top: 5, leading: 7, bottom: 5, trailing: 7))
      .background(.thinMaterial)
      #if canImport(_Translation_SwiftUI)
        .addTranslateView(isPresented: $isDisplayingTranslation, text: text)
      #endif
      #if os(visionOS)
        .clipShape(Capsule())
      #endif
      .cornerRadius(4)
      .padding(theme.statusDisplayStyle == .compact ? 0 : 10)
      .alert(
        "status.editor.media.image-description",
        isPresented: $isDisplayingAlert
      ) {
        Button("alert.button.ok", action: {})
        Button("status.action.copy-text", action: { UIPasteboard.general.string = text })
        #if canImport(_Translation_SwiftUI)
          if #available(iOS 17.4, *) {
            Button("status.action.translate", action: { isDisplayingTranslation = true })
          }
        #endif
      } message: {
        Text(text)
      }
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: .bottomTrailing
      )
    }
  }
}

private struct DisplayData: Identifiable, Hashable {
  let id: String
  let url: URL
  let fallbackUrl: URL?
  let previewUrl: URL?
  let description: String?
  let type: DisplayType
  let accessibilityText: String
  let isLandscape: Bool
  let clampedAspectRatio: CGFloat?
  let standaloneAspectRatio: CGFloat?
  let aspectRatio: CGFloat?

  init?(from attachment: MediaAttachment, useRemoteMedia: Bool, fallbackOnFail: Bool = false, neverLoadVideo: Bool = false) {
    let resolvedUrl = (useRemoteMedia ? (attachment.remoteUrl ?? attachment.url) : attachment.url)
    guard let url = resolvedUrl else { return nil }
    guard let type = attachment.supportedType else { return nil }
    
    id = attachment.id
    if fallbackOnFail {
      let candidateFallback = useRemoteMedia ? attachment.url : attachment.remoteUrl
      fallbackUrl = candidateFallback == url ? nil : candidateFallback
    } else {
      fallbackUrl = nil
    }
    let pUrl = (useRemoteMedia && type == .image ? (attachment.remoteUrl ?? attachment.previewUrl) : attachment.previewUrl) ?? url
    previewUrl = pUrl
    
    var resolvedType = type
    if resolvedType == .image {
      let allExts = [url.pathExtension, attachment.url?.pathExtension, attachment.remoteUrl?.pathExtension, attachment.previewUrl?.pathExtension].compactMap { $0?.lowercased() }
      let videoExts = ["mp4", "m4v", "mov", "webm"]
      if allExts.contains(where: { videoExts.contains($0) }) {
        resolvedType = .video
      }
    }
    
    if neverLoadVideo && (resolvedType == .video || resolvedType == .gifv) && attachment.previewUrl != nil {
      self.type = .image
      self.url = pUrl
    } else {
      self.type = DisplayType(from: resolvedType)
      self.url = url
    }
    
    description = attachment.description
    accessibilityText = Self.getAccessibilityString(from: attachment)
    isLandscape = (attachment.meta?.original?.width ?? 0) > (attachment.meta?.original?.height ?? 0)
    clampedAspectRatio = attachment.clampedAspectRatio
    if let ratio = attachment.aspectRatio {
      standaloneAspectRatio = min(max(ratio, 0.25), 4.0)
    } else {
      standaloneAspectRatio = nil
    }
    aspectRatio = attachment.aspectRatio
  }

  private static func getAccessibilityString(from attachment: MediaAttachment) -> String {
    if let altText = attachment.description {
      "accessibility.image.alt-text-\(altText)"
    } else if let typeDescription = attachment.localizedTypeDescription {
      typeDescription
    } else {
      "accessibility.tabs.profile.picker.media"
    }
  }
}

private enum DisplayType {
  case image
  case av

  init(from attachmentType: MediaAttachment.SupportedType) {
    switch attachmentType {
    case .image:
      self = .image
    case .video, .gifv, .audio:
      self = .av
    }
  }
}

struct StatusRowMediaPreviewView_Previews: PreviewProvider {
  static var previews: some View {
    WrapperForPreview()
  }
}

struct WrapperForPreview: View {
  @State private var isCompact = false
  @State private var isInCaptureMode = false

  var body: some View {
    VStack {
      ScrollView {
        VStack {
          ForEach(1..<5) { number in
            VStack {
              Text("Preview for \(number) item(s)")
              StatusRowMediaPreviewView(
                attachments: Array(repeating: Self.attachment, count: number),
                sensitive: true
              )
            }
            .padding()
            .border(.red)
          }
        }
      }
      .environment(SceneDelegate())
      .environment(UserPreferences.shared)
      .environment(QuickLook.shared)
      .environment(Theme.shared)
      .environment(\.isMediaCompact, isCompact)
      .environment(\.isInCaptureMode, isInCaptureMode)

      Divider()
      Toggle("Compact Mode", isOn: $isCompact.animation())
      Toggle("Capture Mode", isOn: $isInCaptureMode)
    }
    .padding()
  }

  private static let url = URL(
    string: "https://www.upwork.com/catalog-images/c5dffd9b5094556adb26e0a193a1c494")!
  private static let attachment = MediaAttachment.imageWith(url: url)
  private static let local = Locale(identifier: "en")
}

@MainActor
private struct FeaturedImagePreView: View {
  let attachment: MediaAttachment
  let useRemoteMedia: Bool
  let maxSize: CGSize?
  let sensitive: Bool
  var onLoaded: () -> Void = {}

  @Environment(\.isSecondaryColumn) private var isSecondaryColumn: Bool
  @Environment(QuickLook.self) private var quickLook
  @Environment(Theme.self) private var theme
  @Environment(\.isModal) private var isModal: Bool
  @Environment(UserPreferences.self) private var userPreferences

  private var originalWidth: CGFloat {
    CGFloat(attachment.meta?.original?.width ?? 300)
  }

  private var originalHeight: CGFloat {
    CGFloat(attachment.meta?.original?.height ?? 300)
  }

  var body: some View {
    let resolvedUrl = (useRemoteMedia ? (attachment.remoteUrl ?? attachment.url) : attachment.url)
    let fallbackUrl: URL? = {
      if userPreferences.remoteMediaFallbackOnFail {
        let candidateFallback = useRemoteMedia ? attachment.url : attachment.remoteUrl
        return candidateFallback == resolvedUrl ? nil : candidateFallback
      } else {
        return nil
      }
    }()
    if let url = resolvedUrl, let namespace = quickLook.namespace {
      _Layout(originalWidth: originalWidth, originalHeight: originalHeight, maxSize: maxSize) {
        Group {
          RoundedRectangle(cornerRadius: 10).fill(Color.gray)
            .overlay {
              switch attachment.supportedType {
              case .image:
                LazyResizableImage(url: resolvedUrl, fallbackUrl: fallbackUrl) { state in
                  if let image = state.image {
                    image
                      .resizable()
                      .onAppear { onLoaded() }
                      .scaledToFill()
                  } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color.gray)
                  }
                }
              case .gifv, .video, .audio:
                MediaUIAttachmentVideoView(viewModel: .init(url: url, fallbackUrl: fallbackUrl, onReady: { onLoaded() }))
              default:
                EmptyView()
              }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(.gray.opacity(0.35), lineWidth: 1)
            )
            #if os(visionOS)
              .hoverEffect()
            #endif
        }
        .matchedTransitionSource(id: attachment.id, in: namespace)
      }
      .overlay {
        BlurOverLay(sensitive: sensitive, font: .scaledFootnote)
      }
      .overlay {
        AltTextButton(
          text: attachment.description,
          font: theme.statusDisplayStyle == .compact ? .footnote : .body
        )
      }
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }

  private struct _Layout: Layout {
    let originalWidth: CGFloat
    let originalHeight: CGFloat
    let maxSize: CGSize?

    init(originalWidth: CGFloat?, originalHeight: CGFloat?, maxSize: CGSize?) {
      self.originalWidth = originalWidth ?? 200
      self.originalHeight = originalHeight ?? 200
      self.maxSize = maxSize
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
      guard !subviews.isEmpty else { return CGSize.zero }

      if let maxSize { return maxSize }

      return calculateSize(proposal)
    }

    func placeSubviews(
      in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()
    ) {
      guard let view = subviews.first else { return }

      let size = if let maxSize { maxSize } else { calculateSize(proposal) }
      view.place(at: bounds.origin, proposal: ProposedViewSize(size))
    }

    private func calculateSize(_ proposal: ProposedViewSize) -> CGSize {
      var size: CGSize
      switch (proposal.width, proposal.height) {
      case (0, _), (_, 0):
        size = CGSize.zero

      case (nil, nil), (nil, .some(.infinity)), (.some(.infinity), .some(.infinity)),
        (.some(.infinity), nil):
        size = CGSize(width: originalWidth, height: originalWidth)

      case (nil, .some(let height)), (.some(.infinity), .some(let height)):
        let minHeight = min(height, originalWidth)
        if originalHeight == 0 {
          size = CGSize.zero
        } else {
          size = CGSize(width: originalWidth * minHeight / originalHeight, height: minHeight)
        }

      case (.some(let width), .some(.infinity)), (.some(let width), nil):
        if originalWidth == 0 {
          size = CGSize(width: width, height: width)
        } else {
          size = CGSize(width: width, height: width / originalWidth * originalHeight)
        }

      case (.some(let width), .some(let height)):
        // intrinsic size of image fits just fine
        if originalWidth <= width, originalHeight <= height {
          size = CGSize(width: originalWidth, height: originalHeight)
        }

        // shrink image proportionally to fit inside the box
        let xRatio = width / originalWidth
        let yRatio = height / originalHeight
        // use small ratio to fit the image in
        if xRatio < yRatio {
          size = CGSize(width: width, height: originalHeight * xRatio)
        } else {
          size = CGSize(width: originalWidth * yRatio, height: height)
        }
      }

      return CGSize(width: max(size.width, 200), height: min(size.height, 450))
    }
  }
}

@MainActor
private struct StatusRowMediaGridView: View {
  let attachments: [MediaAttachment]
  let sensitive: Bool
  let imageMaxHeight: CGFloat
  let useRemoteMedia: Bool
  let userPreferences: UserPreferences
  let onLoaded: (String) -> Void
  let tabAction: (Int) -> Void

  var body: some View {
    let gridHeight = imageMaxHeight == 300 ? 260.0 : imageMaxHeight
    Group {
      switch attachments.count {
      case 1:
        makeCell(for: 0)
      case 2:
        HStack(spacing: 4) {
          makeCell(for: 0)
          makeCell(for: 1)
        }
        .frame(height: gridHeight)
      case 3:
        HStack(spacing: 4) {
          makeCell(for: 0)
          VStack(spacing: 4) {
            makeCell(for: 1)
            makeCell(for: 2)
          }
        }
        .frame(height: gridHeight)
      case 4:
        VStack(spacing: 4) {
          HStack(spacing: 4) {
            makeCell(for: 0)
            makeCell(for: 1)
          }
          HStack(spacing: 4) {
            makeCell(for: 2)
            makeCell(for: 3)
          }
        }
        .frame(height: gridHeight)
      default:
        HStack(alignment: .top, spacing: 4) {
          VStack(spacing: 4) {
            ForEach(0..<attachments.count, id: \.self) { index in
              if index % 2 == 0 {
                makeCell(for: index, isStandaloneOverride: true)
              }
            }
          }
          VStack(spacing: 4) {
            ForEach(0..<attachments.count, id: \.self) { index in
              if index % 2 == 1 {
                makeCell(for: index, isStandaloneOverride: true)
              }
            }
          }
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .contentShape(RoundedRectangle(cornerRadius: 10))
  }

  @ViewBuilder
  private func makeCell(for index: Int, isStandaloneOverride: Bool = false) -> some View {
    let attachment = attachments[index]
    let isIceShrimp = CurrentInstance.shared.isIceShrimp
    let fallback = userPreferences.remoteMediaFallbackOnFail || (userPreferences.useIceShrimpWorkarounds && isIceShrimp)
    let noVideo = userPreferences.neverLoadVideo

    if let data = DisplayData(from: attachment, useRemoteMedia: useRemoteMedia, fallbackOnFail: fallback, neverLoadVideo: noVideo) {
      MediaGridCell(
        sensitive: sensitive,
        displayData: data,
        isStandalone: isStandaloneOverride || attachments.count == 1,
        onLoaded: { onLoaded(attachment.id) }
      )
      .id(data.url)
      .onTapGesture {
        tabAction(index)
      }
      #if os(visionOS)
        .hoverEffect()
      #endif
    }
  }
}

private struct MediaGridCell: View {
  @Environment(QuickLook.self) private var quickLook
  
  let sensitive: Bool
  let displayData: DisplayData
  var isStandalone: Bool = false
  var onLoaded: () -> Void = {}

  @State private var loadedAspectRatio: CGFloat? = nil

  private var currentAspectRatio: CGFloat? {
    return displayData.standaloneAspectRatio ?? loadedAspectRatio ?? 1.0
  }

  var body: some View {
    if let namespace = quickLook.namespace {
      Group {
        switch displayData.type {
        case .image:
          LazyResizableImage(url: displayData.previewUrl, fallbackUrl: displayData.fallbackUrl) { state in
            if let image = state.image {
              image
                .resizable()
                .onAppear {
                  onLoaded()
                  if displayData.standaloneAspectRatio == nil, loadedAspectRatio == nil, let size = state.imageContainer?.image.size, size.height > 0 {
                    let ratio = size.width / size.height
                    DispatchQueue.main.async {
                      loadedAspectRatio = min(max(ratio, 0.25), 4.0)
                    }
                  }
                }
                .aspectRatio(contentMode: .fill)
                .frame(
                  maxWidth: isStandalone ? .infinity : nil,
                  maxHeight: isStandalone ? .infinity : nil
                )
                .frame(minWidth: 0, maxWidth: isStandalone ? nil : .infinity, minHeight: 0, maxHeight: isStandalone ? nil : .infinity)
            } else if state.isLoading {
              Rectangle()
                .fill(Color.gray)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(.gray.opacity(0.35), lineWidth: 1)
          )
          .overlay {
            BlurOverLay(sensitive: sensitive, font: .scaledFootnote)
          }
          .overlay {
            AltTextButton(text: displayData.description, font: .scaledFootnote)
          }
        case .av:
          MediaUIAttachmentVideoView(viewModel: .init(url: displayData.url, fallbackUrl: displayData.fallbackUrl, onReady: { onLoaded() }))
            .accessibilityAddTraits(.startsMediaSession)
        }
      }
      .matchedTransitionSource(id: displayData.id, in: namespace)
      .if(isStandalone && currentAspectRatio != nil) { view in
        view.aspectRatio(currentAspectRatio, contentMode: .fit)
      }
      .frame(
        maxWidth: isStandalone ? .infinity : nil,
        maxHeight: isStandalone ? .infinity : nil
      )
      .frame(minWidth: 0, maxWidth: isStandalone ? nil : .infinity, minHeight: 0, maxHeight: isStandalone ? nil : .infinity)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(displayData.accessibilityText))
      .accessibilityAddTraits(displayData.type == .image ? [.isImage, .isButton] : .isButton)
    }
  }
}

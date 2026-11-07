import Foundation

public struct MediaAttachment: Codable, Identifiable, Hashable, Equatable {
  public struct MetaContainer: Codable, Equatable {
    public struct Meta: Codable, Equatable {
      public let width: Int?
      public let height: Int?
      public let aspect: Double?
      public let duration: Double?
      public let frameRate: String?

      public init(
        width: Int?,
        height: Int?,
        aspect: Double? = nil,
        duration: Double? = nil,
        frameRate: String? = nil
      ) {
        self.width = width
        self.height = height
        self.aspect = aspect
        self.duration = duration
        self.frameRate = frameRate
      }
    }

    public let original: Meta?
    public let small: Meta?

    public init(original: Meta?, small: Meta? = nil) {
      self.original = original
      self.small = small
    }
  }

  public enum SupportedType: String {
    case image, gifv, video, audio
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public let id: String
  public var type: String
  public var supportedType: SupportedType? {
    SupportedType(rawValue: type)
  }

  public var localizedTypeDescription: String? {
    if let supportedType {
      switch supportedType {
      case .image:
        return NSLocalizedString(
          "accessibility.media.supported-type.image.label", bundle: .main,
          comment: "A localized description of SupportedType.image")
      case .gifv:
        return NSLocalizedString(
          "accessibility.media.supported-type.gifv.label", bundle: .main,
          comment: "A localized description of SupportedType.gifv")
      case .video:
        return NSLocalizedString(
          "accessibility.media.supported-type.video.label", bundle: .main,
          comment: "A localized description of SupportedType.video")
      case .audio:
        return NSLocalizedString(
          "accessibility.media.supported-type.audio.label", bundle: .main,
          comment: "A localized description of SupportedType.audio")
      }
    }
    return nil
  }

  public let url: URL?
  public let previewUrl: URL?
  public let previewRemoteUrl: URL?
  public let remoteUrl: URL?
  public let description: String?
  public let meta: MetaContainer?

  public init(
    id: String,
    type: String,
    url: URL?,
    previewUrl: URL?,
    previewRemoteUrl: URL? = nil,
    remoteUrl: URL? = nil,
    description: String?,
    meta: MetaContainer?
  ) {
    self.id = id
    self.type = type
    self.url = url
    self.previewUrl = previewUrl
    self.previewRemoteUrl = previewRemoteUrl
    self.remoteUrl = remoteUrl
    self.description = description
    self.meta = meta
  }

  public static func imageWith(url: URL) -> MediaAttachment {
    .init(
      id: UUID().uuidString,
      type: "image",
      url: url,
      previewUrl: url,
      previewRemoteUrl: nil,
      remoteUrl: nil,
      description: nil,
      meta: nil)
  }

  public static func videoWith(url: URL) -> MediaAttachment {
    .init(
      id: UUID().uuidString,
      type: "video",
      url: url,
      previewUrl: url,
      previewRemoteUrl: nil,
      remoteUrl: nil,
      description: nil,
      meta: nil)
  }

  /// The aspect ratio of the media
  public var aspectRatio: CGFloat? {
    if let ratio = meta?.original?.resolvedAspectRatio {
      return ratio
    }
    if let ratio = meta?.small?.resolvedAspectRatio {
      return ratio
    }
    return nil
  }

  /// The aspect ratio of the media, clamped to sane bounds so a single very
  /// wide (panorama) or very tall (screenshot) attachment can't blow out
  /// masonry/grid layouts that size cells from this value.
  public var clampedAspectRatio: CGFloat? {
    guard let ratio = aspectRatio else { return nil }
    guard ratio > 0 else { return nil }
    return min(max(ratio, 0.5), 2.0)
  }

  /// Whether this attachment is a visual media type supported in Gallery Mode grids.
  public var isVisualMedia: Bool {
    guard let supportedType else { return false }
    switch supportedType {
    case .image, .gifv, .video:
      if url != nil { return true }
      if remoteUrl != nil { return true }
      if previewUrl != nil { return true }
      if previewRemoteUrl != nil { return true }
      return false
    case .audio:
      return false
    }
  }

  /// Deterministic aspect ratio used by Gallery Mode layout calculation and cell modifiers.
  /// Always returns a bounded positive ratio in `[0.5, 2.0]` (or `1.0` when square cropping is enabled
  /// or when server dimension metadata is absent), preventing post-load layout shifts.
  public func galleryAspectRatio(isSquare: Bool) -> CGFloat {
    if isSquare { return 1.0 }
    guard let clamped = clampedAspectRatio else { return 1.0 }
    guard clamped > 0 else { return 1.0 }
    return clamped
  }

  public struct DisplayInfo: Sendable, Equatable {
    public let url: URL
    public let type: SupportedType
    public let fallbackUrl: URL?
    public let previewUrl: URL?
    public let previewFallbackUrl: URL?

    /// Returns `true` when a distinct static image thumbnail URL is available for `.video` or `.gifv` attachments.
    public var hasStaticPreviewImage: Bool {
      guard let previewUrl else { return false }
      if previewUrl == url { return false }
      let ext = previewUrl.pathExtension.lowercased()
      if ext == "mp4" || ext == "m4v" || ext == "mov" || ext == "webm" {
        return false
      }
      return true
    }
  }

  public func displayInfo(
    useRemoteMedia: Bool = false,
    fallbackOnFail: Bool = false,
    neverLoadVideo: Bool = false,
    isIceShrimp: Bool = false
  ) -> DisplayInfo? {
    let resolvedUrl = useRemoteMedia ? (remoteUrl ?? url) : url
    guard let url = resolvedUrl else { return nil }
    guard let baseType = supportedType else { return nil }

    let fallbackUrl: URL?
    if fallbackOnFail {
      let candidateFallback = useRemoteMedia ? self.url : (remoteUrl ?? self.url)
      fallbackUrl = candidateFallback == url ? nil : candidateFallback
    } else {
      fallbackUrl = nil
    }

    let resolvedType = baseType

    let pUrl = (useRemoteMedia ? (previewRemoteUrl ?? previewUrl) : previewUrl) ?? url

    let pFallbackUrl: URL?
    if fallbackOnFail {
      let candidatePFallback: URL?
      if useRemoteMedia {
        candidatePFallback = self.previewUrl ?? self.url
      } else {
        candidatePFallback = previewRemoteUrl ?? remoteUrl ?? self.url
      }
      pFallbackUrl = candidatePFallback == pUrl ? nil : candidatePFallback
    } else {
      pFallbackUrl = nil
    }

    if neverLoadVideo && (resolvedType == .video || resolvedType == .gifv) && previewUrl != nil {
      return DisplayInfo(url: pUrl, type: .image, fallbackUrl: pFallbackUrl, previewUrl: pUrl, previewFallbackUrl: pFallbackUrl)
    }

    return DisplayInfo(url: url, type: resolvedType, fallbackUrl: fallbackUrl, previewUrl: pUrl, previewFallbackUrl: pFallbackUrl)
  }

}

extension MediaAttachment.MetaContainer.Meta {
  var resolvedAspectRatio: CGFloat? {
    if let aspect, aspect > 0 {
      return CGFloat(aspect)
    }
    if let width, let height, width > 0, height > 0 {
      return CGFloat(width) / CGFloat(height)
    }
    return nil
  }
}

extension MediaAttachment: Sendable {}
extension MediaAttachment.MetaContainer: Sendable {}
extension MediaAttachment.MetaContainer.Meta: Sendable {}
extension MediaAttachment.SupportedType: Sendable {}

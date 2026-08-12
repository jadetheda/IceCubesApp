import Foundation

public struct MediaAttachment: Codable, Identifiable, Hashable, Equatable {
  public struct MetaContainer: Codable, Equatable {
    public struct Meta: Codable, Equatable {
      public let width: Int?
      public let height: Int?
      public let aspect: Double?
      public let duration: Double?
      public let frameRate: String?
    }

    public let original: Meta?
    public let small: Meta?
  }

  public enum SupportedType: String {
    case image, gifv, video, audio
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public let id: String
  public let type: String
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
  public let remoteUrl: URL?
  public let description: String?
  public let meta: MetaContainer?

  public static func imageWith(url: URL) -> MediaAttachment {
    .init(
      id: UUID().uuidString,
      type: "image",
      url: url,
      previewUrl: url,
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
      remoteUrl: nil,
      description: nil,
      meta: nil)
  }

  /// The aspect ratio of the media
  public var aspectRatio: CGFloat? {
    if let original = meta?.original {
      if let aspect = original.aspect { return CGFloat(aspect) }
      if let width = original.width, let height = original.height, height > 0 {
        return CGFloat(width) / CGFloat(height)
      }
    }
    if let small = meta?.small {
      if let aspect = small.aspect { return CGFloat(aspect) }
      if let width = small.width, let height = small.height, height > 0 {
        return CGFloat(width) / CGFloat(height)
      }
    }
    return nil
  }

  /// The aspect ratio of the media, clamped to sane bounds so a single very
  /// wide (panorama) or very tall (screenshot) attachment can't blow out
  /// masonry/grid layouts that size cells from this value.
  public var clampedAspectRatio: CGFloat? {
    guard let ratio = aspectRatio else { return nil }
    return min(max(ratio, 0.5), 2.0)
  }

  public struct DisplayInfo: Sendable, Equatable {
    public let url: URL
    public let type: SupportedType
    public let fallbackUrl: URL?
    public let previewUrl: URL?
  }

  public func displayInfo(
    useRemoteMedia: Bool = false,
    fallbackOnFail: Bool = false,
    neverLoadVideo: Bool = false
  ) -> DisplayInfo? {
    let resolvedUrl = useRemoteMedia ? (remoteUrl ?? url) : url
    guard let url = resolvedUrl else { return nil }
    guard let baseType = supportedType else { return nil }

    let fallbackUrl: URL?
    if fallbackOnFail {
      let candidateFallback = useRemoteMedia ? self.url : remoteUrl
      fallbackUrl = candidateFallback == url ? nil : candidateFallback
    } else {
      fallbackUrl = nil
    }

    var resolvedType = baseType
    if resolvedType == .image {
      let allExts = [url.pathExtension, self.url?.pathExtension, remoteUrl?.pathExtension, previewUrl?.pathExtension].compactMap { $0?.lowercased() }
      let videoExts = ["mp4", "m4v", "mov", "webm"]
      if allExts.contains(where: { videoExts.contains($0) }) || meta?.original?.duration != nil || meta?.original?.frameRate != nil {
        resolvedType = .video
      }
    }

    let pUrl = (useRemoteMedia && resolvedType == .image ? (remoteUrl ?? previewUrl) : previewUrl) ?? url

    if neverLoadVideo && (resolvedType == .video || resolvedType == .gifv) && previewUrl != nil {
      return DisplayInfo(url: pUrl, type: .image, fallbackUrl: fallbackUrl, previewUrl: pUrl)
    }

    return DisplayInfo(url: url, type: resolvedType, fallbackUrl: fallbackUrl, previewUrl: pUrl)
  }

}

extension MediaAttachment: Sendable {}
extension MediaAttachment.MetaContainer: Sendable {}
extension MediaAttachment.MetaContainer.Meta: Sendable {}
extension MediaAttachment.SupportedType: Sendable {}

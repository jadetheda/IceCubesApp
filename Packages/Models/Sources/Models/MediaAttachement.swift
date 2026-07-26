import Foundation

public struct MediaAttachment: Codable, Identifiable, Hashable, Equatable {
  public struct MetaContainer: Codable, Equatable {
    public struct Meta: Codable, Equatable {
      public let width: Int?
      public let height: Int?
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
    if let original = meta?.original, let width = original.width, let height = original.height, height > 0 {
      return CGFloat(width) / CGFloat(height)
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
}

extension MediaAttachment: Sendable {}
extension MediaAttachment.MetaContainer: Sendable {}
extension MediaAttachment.MetaContainer.Meta: Sendable {}
extension MediaAttachment.SupportedType: Sendable {}

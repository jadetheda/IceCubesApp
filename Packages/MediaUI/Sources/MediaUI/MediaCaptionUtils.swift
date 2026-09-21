import Foundation
import Models
import Env
import ImageIO

public struct MediaCaptionUtils {
  public static func embedCaption(into data: Data, caption: String) -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let type = CGImageSourceGetType(source) else { return data }
    
    // Only apply to static images to prevent breaking animated GIFs or WebPs
    let count = CGImageSourceGetCount(source)
    guard count == 1 else { return data }
    
    let mutableData = NSMutableData()
    let isWebP = (type as String) == "org.webmproject.webp"
    
    let outputType: CFString
    if isWebP {
        outputType = "public.heic" as CFString
    } else {
        outputType = type
    }
    
    guard let destination = CGImageDestinationCreateWithData(mutableData, outputType, 1, nil) else { return data }
    
    var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
    
    if isWebP {
        metadata[kCGImageDestinationLossyCompressionQuality as String] = 1.0
    }
    
    var iptc = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
    iptc[kCGImagePropertyIPTCCaptionAbstract as String] = caption
    metadata[kCGImagePropertyIPTCDictionary as String] = iptc

    var tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
    tiff[kCGImagePropertyTIFFImageDescription as String] = caption
    metadata[kCGImagePropertyTIFFDictionary as String] = tiff
    
    CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return data }
    
    return mutableData as Data
  }
  public static func createCaption(from exportMetadata: PhotoExportMetadata?, preferences: UserPreferences) -> String? {
    guard let exportMetadata else { return nil }
    var caption = ""
    if preferences.embedPostTextInMedia, let text = exportMetadata.postText {
      caption += text + "\n\n"
    }
    if preferences.embedPostTagsInMedia, let tags = exportMetadata.postTags, !tags.isEmpty {
      caption += tags.map { "#\($0)" }.joined(separator: " ") + "\n\n"
    }
    if preferences.embedPostUrlInMedia, let url = exportMetadata.postUrl {
      caption += url.absoluteString
    }
    
    let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

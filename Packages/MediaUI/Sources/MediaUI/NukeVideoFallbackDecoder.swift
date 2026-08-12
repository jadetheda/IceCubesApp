import Foundation
import Nuke
import UIKit
import AVFoundation

public final class NukeVideoFallbackDecoder: ImageDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> ImageContainer {
        guard isVideo(data) else {
            throw ImageDecodingError.unknown
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let asset = AVAsset(url: tempURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return ImageContainer(image: UIImage(cgImage: cgImage))
        } catch {
            throw ImageDecodingError.unknown
        }
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? {
        return nil
    }

    private func isVideo(_ data: Data) -> Bool {
        guard data.count > 12 else { return false }
        if let ftyp = String(data: data[4..<8], encoding: .ascii) {
            return ftyp == "ftyp"
        }
        return false
    }
}

public struct MediaUIConfiguration {
    public static func registerVideoFallbackDecoder() {
        ImageDecoderRegistry.shared.register { context in
            guard context.data.count > 12, let ftyp = String(data: context.data[4..<8], encoding: .ascii), ftyp == "ftyp" else {
                return nil
            }
            return NukeVideoFallbackDecoder()
        }
    }
}

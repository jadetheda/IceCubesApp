import Foundation
import CoreGraphics
import Compression

#if canImport(UIKit)
import UIKit
#endif

public struct PluraldawnDecoder {
    private static let whitelistHosts: Set<String> = [
        "pool.jortage.com", "blob.jortage.com", "us.pool.jortage.com", "us.blob.jortage.com",
        "cn.pool.jortage.com", "cn.blob.jortage.com", "cdn.pluralkit.me", "cdn.plural.gg",
        "scratchupload.xyz", "scratchupload.org", "files.y2k.diy"
    ]

    public static func decode(from url: URL) async -> PluraldawnSystem? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) ??
                          CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            #if canImport(UIKit)
            guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else { return nil }
            return extract(from: cgImage)
            #else
            return nil
            #endif
        }
        
        return extract(from: image)
    }
    
    private static func extract(from image: CGImage) -> PluraldawnSystem? {
        let width = image.width
        let height = image.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var extractedBytes: [UInt8] = []
        // Read pixels from bottom-right backwards (stepping by 4 bytes)
        for i in stride(from: rawData.count - bytesPerPixel, through: 0, by: -bytesPerPixel) {
            let r = rawData[i]
            let g = rawData[i+1]
            let b = rawData[i+2]
            
            let byte = ((r & 7) << 5) | ((g & 3) << 3) | (b & 7)
            extractedBytes.append(byte)
        }
        
        let magic = "PlDw2".data(using: .utf8)!
        guard extractedBytes.count > magic.count else { return nil }
        
        let extractedData = Data(extractedBytes)
        guard let magicRange = extractedData.range(of: magic) else { return nil }
        
        let payload = extractedData.subdata(in: magicRange.upperBound..<extractedData.count)
        
        // Decompress using Compression framework to gracefully handle trailing garbage
        let decompressed = payload.withUnsafeBytes { srcPointer -> Data? in
            guard let srcBase = srcPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            
            var stream = compression_stream()
            guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { return nil }
            defer { compression_stream_destroy(&stream) }
            
            stream.src_ptr = srcBase
            stream.src_size = payload.count
            
            let bufferSize = 32768
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            
            var result = Data()
            
            while true {
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize
                
                let status = compression_stream_process(&stream, 0)
                
                if status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END {
                    let decodedCount = bufferSize - stream.dst_size
                    if decodedCount > 0 {
                        result.append(buffer, count: decodedCount)
                    }
                    if status == COMPRESSION_STATUS_END {
                        return result
                    }
                    if stream.dst_size > 0 && stream.src_size == 0 {
                        // Needed more source data but we are out, stream may be truncated
                        return nil 
                    }
                } else {
                    return nil
                }
            }
        }
        
        guard let decompressedData = decompressed, let string = String(data: decompressedData, encoding: .utf8) else { return nil }
        
        let groups = string.components(separatedBy: "\u{001D}")
        guard groups.count >= 5 else { return nil }
        
        let ids = groups[0].components(separatedBy: "\u{001E}")
        let names = groups[1].components(separatedBy: "\u{001E}")
        let indicators = groups[2].components(separatedBy: "\u{001E}")
        let avatars = groups[3].components(separatedBy: "\u{001E}")
        let fonts = groups[4].components(separatedBy: "\u{001E}")
        
        let count = min(ids.count, names.count, indicators.count, avatars.count, fonts.count)
        var members: [PluraldawnMember] = []
        
        for i in 0..<count {
            let id = ids[i]
            if id.isEmpty { continue }
            let name = names[i]
            let indicatorStr = indicators[i]
            let emoji = indicatorStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let avatar = avatars[i]
            let font = fonts[i]
            
            let member = PluraldawnMember(id: id, name: name, emoji: emoji, avatar: avatar, font: font)
            
            if avatar == "emoji" {
                members.append(member)
            } else if let url = member.avatarURL, let host = url.host, whitelistHosts.contains(host) {
                members.append(member)
            }
        }
        
        return PluraldawnSystem(members: members)
    }
}

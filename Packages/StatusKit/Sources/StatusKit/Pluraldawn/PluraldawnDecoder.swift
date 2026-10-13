import Foundation
import CoreGraphics
import Compression

#if canImport(UIKit)
import UIKit
#endif

public struct PluraldawnDecoder {
    private static let permittedAvatarOrigins: [String] = [
        "emoji",
        "https://files.y2k.diy/",
        "https://exa.y2k.diy/junk/noise.png",
        "https://pool.jortage.com/",
        "https://blob.jortage.com/",
        "https://us.pool.jortage.com/",
        "https://us.blob.jortage.com/",
        "https://cn.pool.jortage.com/",
        "https://cn.blob.jortage.com/",
        "https://cdn.pluralkit.me/files/",
        "https://cdn.pluralkit.me/",
        "https://cdn.plural.gg/",
        "https://scratchupload.xyz/",
        "https://scratchupload.org/",
    ]

    private static let fontStyleNames: [String] = [
        "normal",
        "smallcaps",
        "small",
        "monospace"
    ]

    private static let whitelistHosts: Set<String> = [
        "pool.jortage.com", "blob.jortage.com", "us.pool.jortage.com", "us.blob.jortage.com",
        "cn.pool.jortage.com", "cn.blob.jortage.com", "cdn.pluralkit.me", "cdn.plural.gg",
        "scratchupload.xyz", "scratchupload.org", "files.y2k.diy", "exa.y2k.diy"
    ]

    public static func decode(from url: URL) async -> PluraldawnSystem? {
        let resolvedURL = resolveOriginalAvatarURL(url)
        var downloadedData: Data? = nil
        if let (data, response) = try? await URLSession.shared.data(from: resolvedURL) {
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    downloadedData = data
                }
            } else {
                downloadedData = data
            }
        }
        if downloadedData == nil {
            if resolvedURL != url {
                if let (data, response) = try? await URLSession.shared.data(from: url) {
                    if let http = response as? HTTPURLResponse {
                        if http.statusCode == 200 {
                            downloadedData = data
                        }
                    } else {
                        downloadedData = data
                    }
                }
            }
        }
        guard let data = downloadedData else { return nil }
        
        // 1. Try bit-exact PNG chunk decode first to bypass CoreGraphics gamma/color alteration
        if let (pixels, bpp) = decodePNGPixels(from: data) {
            if let system = extractFromPixels(pixels, bpp: bpp) {
                return system
            }
        }
        
        // 2. Fall back to CGImage decode
        guard let dataProvider = CGDataProvider(data: data as CFData) else { return nil }
        var optionalImage: CGImage? = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        if optionalImage == nil {
            optionalImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
        
        if let unwrappedImage = optionalImage {
            return extractFromCGImage(unwrappedImage)
        }
        
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        guard let cgImage = uiImage.cgImage else { return nil }
        return extractFromCGImage(cgImage)
        #else
        return nil
        #endif
    }
    
    static func resolveOriginalAvatarURL(_ url: URL) -> URL {
        var currentURL = url
        // 1. If it's a proxy with an encoded original URL in query parameters (?url=https%3A%2F%2F...)
        // (Used by Misskey, IceShrimp, Sharkey, Firefish, etc.)
        if let components = URLComponents(url: currentURL, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    if item.name == "url" {
                        if let targetStr = item.value {
                            if let targetURL = URL(string: targetStr) {
                                if targetURL.scheme != nil {
                                    if targetURL != currentURL {
                                        currentURL = targetURL
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        var str = currentURL.absoluteString
        
        // Upgrade thumbnails / small variants to original full-resolution
        if str.contains("/attachment/small/") {
            str = str.replacingOccurrences(of: "/attachment/small/", with: "/attachment/original/")
        }
        
        if str.contains("/accounts/avatars/") {
            if str.contains("/small/") {
                str = str.replacingOccurrences(of: "/small/", with: "/original/")
            }
            if str.hasSuffix("/small.png") {
                str = str.replacingOccurrences(of: "/small.png", with: "/original.png")
            }
            if str.hasSuffix("/small.webp") {
                str = str.replacingOccurrences(of: "/small.webp", with: "/original.png")
            }
        }
        
        // Replace webp proxies and endpoints with lossless png
        if str.contains("/proxy/avatar.webp") {
            str = str.replacingOccurrences(of: "/proxy/avatar.webp", with: "/proxy/avatar.png")
        } else if str.contains("/avatar.webp") {
            str = str.replacingOccurrences(of: "/avatar.webp", with: "/avatar.png")
        }
        
        if str.contains("/proxy/image.webp") {
            str = str.replacingOccurrences(of: "/proxy/image.webp", with: "/proxy/image.png")
        } else if str.contains("/image.webp") {
            str = str.replacingOccurrences(of: "/image.webp", with: "/image.png")
        }
        
        if str.contains("/attachment/original/") {
            if str.hasSuffix(".webp") {
                str = String(str.dropLast(5)) + ".png"
            }
        }
        
        // Mastodon v2 cache API original format request
        if str.contains("/api/v2/cache/avatar/") {
            if !str.contains("format=original") {
                let separator = str.contains("?") ? "&" : "?"
                str = str + separator + "format=original"
            }
        }
        
        if let newUrl = URL(string: str) {
            return newUrl
        }
        return currentURL
    }
    
    // Direct PNG chunk pixel decoder: uncompresses IDAT scanlines and reverses PNG filters
    // without any color profile conversion, ensuring LSB data remains intact.
    private static func decodePNGPixels(from data: Data) -> (pixels: [UInt8], bpp: Int)? {
        guard data.count > 8 else { return nil }
        let data = data.startIndex == 0 ? data : Data(data)
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        for idx in 0..<8 {
            if data[idx] != pngHeader[idx] { return nil }
        }
        
        var pos = 8
        var idat = Data()
        var width: Int = 0
        var height: Int = 0
        var colorType: UInt8 = 0
        
        while pos + 8 <= data.count {
            let length = Int(UInt32(data[pos]) << 24 | UInt32(data[pos+1]) << 16 | UInt32(data[pos+2]) << 8 | UInt32(data[pos+3]))
            if length < 0 || length > data.count - pos - 12 { break }
            let chunkType = data.subdata(in: (pos + 4)..<(pos + 8))
            pos += 8
            
            let chunkData = data.subdata(in: pos..<(pos + length))
            pos += length + 4 // skip CRC
            
            if chunkType == "IHDR".data(using: .ascii) {
                guard chunkData.count >= 13 else { return nil }
                width = Int(UInt32(chunkData[0]) << 24 | UInt32(chunkData[1]) << 16 | UInt32(chunkData[2]) << 8 | UInt32(chunkData[3]))
                height = Int(UInt32(chunkData[4]) << 24 | UInt32(chunkData[5]) << 16 | UInt32(chunkData[6]) << 8 | UInt32(chunkData[7]))
                let bitDepth = chunkData[8]
                colorType = chunkData[9]
                let compressionMethod = chunkData[10]
                let filterMethod = chunkData[11]
                let interlaceMethod = chunkData[12]
                if bitDepth != 8 { return nil }
                if colorType != 2 && colorType != 6 { return nil }
                if compressionMethod != 0 || filterMethod != 0 { return nil }
                if interlaceMethod != 0 { return nil } // Fall back to CGImage decode for Adam7
            } else if chunkType == "IDAT".data(using: .ascii) {
                if idat.count > 10 * 1024 * 1024 { return nil }
                idat.append(chunkData)
            } else if chunkType == "IEND".data(using: .ascii) {
                break
            }
        }
        
        guard width > 0 else { return nil }
        guard height > 0 else { return nil }
        guard width <= 10000 else { return nil }
        guard height <= 10000 else { return nil }
        guard !idat.isEmpty else { return nil }
        guard let raw = decompressPayload(idat) else { return nil }
        
        let bpp = colorType == 6 ? 4 : 3
        let stride = width * bpp
        guard raw.count >= height * (stride + 1) else { return nil }
        
        var pixels = [UInt8](repeating: 0, count: width * height * bpp)
        var prevRow = [UInt8](repeating: 0, count: stride)
        var rawPos = 0
        var outPos = 0
        
        for _ in 0..<height {
            let filter = raw[rawPos]
            rawPos += 1
            var row = [UInt8](raw[rawPos..<(rawPos + stride)])
            rawPos += stride
            
            switch filter {
            case 1: // Sub
                for x in bpp..<stride {
                    row[x] = row[x] &+ row[x - bpp]
                }
            case 2: // Up
                for x in 0..<stride {
                    row[x] = row[x] &+ prevRow[x]
                }
            case 3: // Average
                for x in 0..<stride {
                    let left = x >= bpp ? Int(row[x - bpp]) : 0
                    let up = Int(prevRow[x])
                    row[x] = row[x] &+ UInt8((left + up) >> 1)
                }
            case 4: // Paeth
                for x in 0..<stride {
                    let a = x >= bpp ? Int(row[x - bpp]) : 0
                    let b = Int(prevRow[x])
                    let c = x >= bpp ? Int(prevRow[x - bpp]) : 0
                    let p = a + b - c
                    let pa = abs(p - a)
                    let pb = abs(p - b)
                    let pc = abs(p - c)
                    let pr: Int
                    if pa <= pb && pa <= pc {
                        pr = a
                    } else if pb <= pc {
                        pr = b
                    } else {
                        pr = c
                    }
                    row[x] = row[x] &+ UInt8(pr & 0xFF)
                }
            default:
                break
            }
            
            prevRow = row
            for x in 0..<stride {
                pixels[outPos + x] = row[x]
            }
            outPos += stride
        }
        
        return (pixels, bpp)
    }

    private static func extractFromCGImage(_ image: CGImage) -> PluraldawnSystem? {
        let width = image.width
        let height = image.height
        guard width > 0 else { return nil }
        guard height > 0 else { return nil }
        guard width <= 10000 else { return nil }
        guard height <= 10000 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let alphaInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let byteOrder = CGBitmapInfo.byteOrder32Big.rawValue
        let bitmapInfoValue = alphaInfo | byteOrder
        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfoValue) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return extractFromPixels(rawData, bpp: bytesPerPixel)
    }

    private static func extractFromPixels(_ pixels: [UInt8], bpp: Int) -> PluraldawnSystem? {
        guard bpp >= 3, pixels.count >= bpp else { return nil }
        
        // 1. Try PlDw2 format (v2 pixel packing: 3 red, 2 green, 3 blue)
        var v2Bytes = [UInt8]()
        v2Bytes.reserveCapacity(pixels.count / bpp)
        for i in stride(from: pixels.count - bpp, through: 0, by: -bpp) {
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            let byte = ((r & 7) << 5) | ((g & 3) << 3) | (b & 7)
            v2Bytes.append(byte)
        }
        
        let v2Data = Data(v2Bytes)
        if let magic = "PlDw2".data(using: .utf8),
           let magicRange = v2Data.range(of: magic) {
            let payload = v2Data.subdata(in: magicRange.upperBound..<v2Data.count)
            if let decompressed = decompressPayload(payload) {
                if let system = parsePlDw2(decompressed) {
                    return system
                }
            }
        }
        
        // 2. Try PlDon format (v1 pixel packing: 2 red, 3 green, 3 blue)
        var v1Bytes = [UInt8]()
        v1Bytes.reserveCapacity(pixels.count / bpp)
        for i in stride(from: pixels.count - bpp, through: 0, by: -bpp) {
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            let byte = ((r & 3) << 6) | ((g & 7) << 3) | (b & 7)
            v1Bytes.append(byte)
        }
        
        let v1Data = Data(v1Bytes)
        if let magic = "PlDon".data(using: .utf8),
           let magicRange = v1Data.range(of: magic) {
            let payload = v1Data.subdata(in: magicRange.upperBound..<v1Data.count)
            let nullByte: UInt8 = 0
            let jsonPayload: Data
            if let nullIdx = payload.firstIndex(of: nullByte) {
                jsonPayload = payload.subdata(in: payload.startIndex..<nullIdx)
            } else {
                jsonPayload = payload
            }
            if let system = parsePlDon(jsonPayload) {
                return system
            }
        }
        
        return nil
    }

    private static func parsePlDw2(_ data: Data) -> PluraldawnSystem? {
        var offset = 0
        guard let ids = readGroup(data: data, offset: &offset, prefixes: nil) else { return nil }
        guard let names = readGroup(data: data, offset: &offset, prefixes: nil) else { return nil }
        guard let indicators = readGroup(data: data, offset: &offset, prefixes: nil) else { return nil }
        guard let avatars = readGroup(data: data, offset: &offset, prefixes: permittedAvatarOrigins) else { return nil }
        let fonts = readGroup(data: data, offset: &offset, prefixes: fontStyleNames)
        
        let count = min(ids.count, names.count, indicators.count, avatars.count)
        guard count > 0 else { return nil }
        
        var members: [PluraldawnMember] = []
        for i in 0..<count {
            let id = ids[i].first ?? ""
            if id.isEmpty { continue }
            let name = names[i].first ?? ""
            let emojiList = indicators[i].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let avatar = avatars[i].first ?? ""
            var font = "normal"
            if let fontsList = fonts {
                if i < fontsList.count {
                    font = fontsList[i].first ?? "normal"
                }
            }
            
            let member = PluraldawnMember(id: id, name: name, emoji: emojiList, avatar: avatar, font: font)
            
            if avatar == "emoji" {
                members.append(member)
            } else if let url = member.avatarURL {
                if let host = url.host {
                    if whitelistHosts.contains(host) {
                        members.append(member)
                    }
                }
            }
        }
        
        guard !members.isEmpty else { return nil }
        return PluraldawnSystem(members: members)
    }

    private static func readGroup(data: Data, offset: inout Int, prefixes: [String]?) -> [[String]]? {
        guard offset < data.count else { return nil }
        if data[offset] == 0x04 { return nil } // End of transmission (0x04)
        
        var groupItems: [[String]] = []
        var buffer = [UInt8]()
        var currentPrefix: String? = nil
        
        while offset < data.count {
            let b = data[offset]
            offset += 1
            
            if b == 0x1E || b == 0x1D { // Record Separator (0x1E) or Group Separator (0x1D)
                var str = String(decoding: buffer, as: UTF8.self)
                if let prefix = currentPrefix {
                    str = prefix + str
                }
                let splitItems = str.components(separatedBy: "\u{001F}")
                groupItems.append(splitItems)
                buffer.removeAll(keepingCapacity: true)
                currentPrefix = nil
                
                if b == 0x1D {
                    break
                }
            } else if prefixes != nil && buffer.isEmpty && b == 0x10 { // Data Link Escape (0x10)
                guard offset < data.count else { return nil }
                let prefixIndex = Int(data[offset])
                offset += 1
                if let prefixes = prefixes, prefixIndex < prefixes.count {
                    currentPrefix = prefixes[prefixIndex]
                }
            } else {
                buffer.append(b)
            }
        }
        return groupItems
    }

    private struct PlDonFormat: Codable {
        struct Member: Codable {
            let id: String?
            let name: String?
            let emoji: PlDonEmoji?
            let avatar: String?
            let font: String?
        }
        enum PlDonEmoji: Codable {
            case single(String)
            case multiple([String])
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let arr = try? container.decode([String].self) {
                    self = .multiple(arr)
                } else if let str = try? container.decode(String.self) {
                    self = .single(str)
                } else {
                    self = .multiple([])
                }
            }
            
            func encode(to encoder: Encoder) throws {}
            
            var list: [String] {
                switch self {
                case .single(let s): return [s]
                case .multiple(let a): return a
                }
            }
        }
        let members: [Member]?
    }

    private static func parsePlDon(_ data: Data) -> PluraldawnSystem? {
        guard let decoded = try? JSONDecoder().decode(PlDonFormat.self, from: data),
              let rawMembers = decoded.members else { return nil }
        
        var members: [PluraldawnMember] = []
        for m in rawMembers {
            guard let id = m.id else { continue }
            guard !id.isEmpty else { continue }
            guard let name = m.name else { continue }
            guard let avatar = m.avatar else { continue }
            let emoji = m.emoji?.list ?? []
            let font = m.font ?? "normal"
            let member = PluraldawnMember(id: id, name: name, emoji: emoji, avatar: avatar, font: font)
            if avatar == "emoji" {
                members.append(member)
            } else if let url = member.avatarURL {
                if let host = url.host {
                    if whitelistHosts.contains(host) {
                        members.append(member)
                    }
                }
            }
        }
        guard !members.isEmpty else { return nil }
        return PluraldawnSystem(members: members)
    }

    private static func decompressPayload(_ payload: Data) -> Data? {
        guard !payload.isEmpty else { return nil }
        return payload.withUnsafeBytes { (srcPointer: UnsafeRawBufferPointer) -> Data? in
            guard let baseAddress = srcPointer.baseAddress else { return nil }
            let srcBase = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            let bufferSize = 32768
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            
            var stream = compression_stream(
                dst_ptr: buffer,
                dst_size: bufferSize,
                src_ptr: srcBase,
                src_size: payload.count,
                state: nil
            )
            guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { return nil }
            defer { compression_stream_destroy(&stream) }
            
            var result = Data()
            
            while true {
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize
                let prevSrcSize = stream.src_size
                
                let status = compression_stream_process(&stream, 0)
                
                if status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END {
                    let decodedCount = bufferSize - stream.dst_size
                    if decodedCount > 0 {
                        result.append(buffer, count: decodedCount)
                        if result.count > 5 * 1024 * 1024 { return nil }
                    }
                    if status == COMPRESSION_STATUS_END {
                        return result
                    }
                    if decodedCount == 0 && stream.src_size == prevSrcSize {
                        return nil
                    }
                    if stream.dst_size > 0 && stream.src_size == 0 {
                        return nil 
                    }
                } else {
                    return nil
                }
            }
        }
    }
}

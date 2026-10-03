import Foundation
import Compression

let string = "PluraldawnTestSystem123"
let data = string.data(using: .utf8)!

let compressedData = try! (data as NSData).compressed(using: .zlib) as Data
print("Compressed size: \(compressedData.count)")

var payloadWithGarbage = compressedData
payloadWithGarbage.append(Data([0x00, 0x01, 0x02, 0x03, 0x04]))

do {
    let decompressed = try (payloadWithGarbage as NSData).decompressed(using: .zlib) as Data
    print("Decompressed string: \(String(data: decompressed, encoding: .utf8) ?? "nil")")
} catch {
    print("Error decompressing: \(error)")
}

import Foundation
import UIKit
import CoreGraphics

func decodePlDw2(image: UIImage) -> [String]? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var rawData = [UInt8](repeating: 0, count: width * height * 4)
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let context = CGContext(data: &rawData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard context != nil else { return nil }
    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    var bytes = [UInt8]()
    
    var j = 0
    let magic = Array("PlDw2".utf8)
    
    var i = rawData.count - 1
    while i >= 3 {
        let r = rawData[i - 3]
        let g = rawData[i - 2]
        let b = rawData[i - 1]
        
        let byte = ((r & 7) << 5) | ((g & 3) << 3) | (b & 7)
        bytes.append(byte)
        
        if j == magic.count {
            for k in 0..<magic.count {
                if bytes[k] != magic[k] {
                    return nil
                }
            }
        }
        
        // how do we know when to stop?
        // if we just read all pixels, we have a lot of garbage at the end.
        // fflate.decompressSync stops when the deflate stream ends.
        
        i -= 4
        j += 1
    }
    
    return []
}

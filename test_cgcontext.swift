import CoreGraphics
let colorSpace = CGColorSpaceCreateDeviceRGB()
var rawData = [UInt8](repeating: 0, count: 100)
let context = CGContext(data: &rawData, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 40, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

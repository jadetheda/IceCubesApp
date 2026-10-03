import re
with open("Packages/StatusKit/Sources/StatusKit/Pluraldawn/PluraldawnDecoder.swift", "r") as f:
    content = f.read()

target = """        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {"""

replacement = """        let alphaInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let byteOrder = CGBitmapInfo.byteOrder32Big.rawValue
        let bitmapInfoValue = alphaInfo | byteOrder
        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfoValue) else {"""

if target in content:
    content = content.replace(target, replacement)
    print("Fixed bitwise OR")

target2 = """        let min1 = min(ids.count, names.count)
        let min2 = min(indicators.count, avatars.count)
        let count = min(min(min1, min2), fonts.count)"""

replacement2 = """        let min1 = min(ids.count, names.count)
        let min2 = min(indicators.count, avatars.count)
        let min3 = min(min1, min2)
        let count = min(min3, fonts.count)"""

if target2 in content:
    content = content.replace(target2, replacement2)
    print("Fixed nested min")

with open("Packages/StatusKit/Sources/StatusKit/Pluraldawn/PluraldawnDecoder.swift", "w") as f:
    f.write(content)


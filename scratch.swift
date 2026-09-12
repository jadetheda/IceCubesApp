import Foundation

let versionStr = "3.5.3 (compatible; Pixelfed 0.12.10)"
var pixelfedVersion: Float {
    guard versionStr.contains("Pixelfed") else { return 0 }
    if let range = versionStr.range(of: "Pixelfed ") {
        let substr = versionStr[range.upperBound...]
        // we want to parse "0.12"
        let components = substr.split(separator: ".")
        if components.count >= 2 {
            let majorMinor = "\(components[0]).\(components[1])"
            return Float(majorMinor) ?? 0
        }
    }
    return 0
}
print("Pixelfed version: \(pixelfedVersion)")

import Foundation

var asMarkdown = "Hello world\n\n[#swift](https://iceshrimp.net/tags/swift) [＃fediverse](https://iceshrimp.net/tags/fediverse)"
let mdRegex = try! NSRegularExpression(pattern: "(?:\\s*\\[[#＃].*?\\]\\([^\\)]+\\))+\\s*$", options: .caseInsensitive)
let mdRange = NSRange(location: 0, length: asMarkdown.utf16.count)
let result = mdRegex.stringByReplacingMatches(in: asMarkdown, options: [], range: mdRange, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
print("Result:", result)

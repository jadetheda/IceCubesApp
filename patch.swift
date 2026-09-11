import Foundation

let path = "Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift"
var contents = try! String(contentsOfFile: path, encoding: .utf8)

let target = """
  private actor ServerSoftwareCache {
    private var values: [String: String] = [:]
    func value(for server: String) -> String? {
      values[server]
    }
    func set(_ software: String, for server: String) {
      values[server] = software
    }
  }
"""

let replacement = """
  private actor ServerSoftwareCache {
    private var values: [String: String] = [:]
    init() {
      if let data = UserDefaults.standard.data(forKey: "serverSoftwareCache"),
         let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
         self.values = decoded
      }
    }
    func value(for server: String) -> String? {
      values[server]
    }
    func set(_ software: String, for server: String) {
      values[server] = software
      if let data = try? JSONEncoder().encode(values) {
        UserDefaults.standard.set(data, forKey: "serverSoftwareCache")
      }
    }
  }
"""

if let range = contents.range(of: target) {
    contents.replaceSubrange(range, with: replacement)
    try! contents.write(toFile: path, atomically: true, encoding: .utf8)
    print("Replaced!")
} else {
    print("Target not found. Let's try matching with regex.")
    
    // Fallback regex
    let regex = try! NSRegularExpression(pattern: "private actor ServerSoftwareCache \\{.*?\\}", options: [.dotMatchesLineSeparators])
    let range = NSRange(location: 0, length: contents.utf16.count)
    contents = regex.stringByReplacingMatches(in: contents, options: [], range: range, withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
    try! contents.write(toFile: path, atomically: true, encoding: .utf8)
    print("Replaced via regex!")
}

import Foundation

struct URLs: Codable {
    let streaming: URL?
    let status: URL?
}

let json = """
{"streaming":"wss://aethy.com","status":""}
""".data(using: .utf8)!

do {
    let urls = try JSONDecoder().decode(URLs.self, from: json)
    print("Success: \(urls)")
} catch {
    print("Error: \(error)")
}

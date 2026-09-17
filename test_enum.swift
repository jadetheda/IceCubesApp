import Foundation

struct MediaAttachment: Hashable, Codable {
    let id: String
}

enum WindowDestinationMedia: Hashable, Codable {
  case mediaViewer(attachments: [MediaAttachment], selectedAttachment: MediaAttachment)
}

let value = WindowDestinationMedia.mediaViewer(attachments: [MediaAttachment(id: "1")], selectedAttachment: MediaAttachment(id: "1"))
let data = try! JSONEncoder().encode(value)
print(String(data: data, encoding: .utf8)!)

import Foundation

struct Meta: Codable { let duration: Double? }
struct MetaContainer: Codable { let original: Meta? }
struct MediaAttachment: Codable {
  let id: String
  let type: String
  let url: URL?
  let previewUrl: URL?
  let remoteUrl: URL?
  let previewRemoteUrl: URL?
  let meta: MetaContainer?
}

let json = """
{
  "id": "1",
  "type": "video",
  "url": "https://possums.gay/files/7962fd41-8ea7-404c-a3ff-db908259cba9",
  "preview_url": "https://possums.gay/files/7962fd41-8ea7-404c-a3ff-db908259cba9",
  "remote_url": "https://baraag.net/files/7962fd41-8ea7-404c-a3ff-db908259cba9",
  "preview_remote_url": "https://baraag.net/files/7962fd41-8ea7-404c-a3ff-db908259cba9",
  "meta": null
}
"""

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let att = try! decoder.decode(MediaAttachment.self, from: json.data(using: .utf8)!)

print("Type:", att.type)

import Foundation
struct MisskeyStreamMessage: Encodable {
  let type: String
  let body: MisskeyStreamMessageBody
}
struct MisskeyStreamMessageBody: Encodable {
  let channel: String
  let id: String
}

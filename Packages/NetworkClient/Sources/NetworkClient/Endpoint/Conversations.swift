import Foundation

public enum Conversations: Endpoint {
  case conversations(maxId: String?)
  case delete(id: String)
  case read(id: String)
  case messages(id: String)
  case send(userId: String, text: String)

  public func path() -> String {
    switch self {
    case .conversations:
      "conversations"
    case let .delete(id):
      "conversations/\(id)"
    case let .read(id):
      "conversations/\(id)/read"
    case let .messages(id):
      "conversations/\(id)/messages"
    case .send:
      "conversations/send"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .conversations(maxId):
      makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    default:
      nil
    }
  }

  public var jsonValue: Encodable? {
    switch self {
    case let .send(userId, text):
      return MessageData(userId: userId, text: text)
    default:
      return nil
    }
  }

  private struct MessageData: Encodable {
    let userId: String
    let text: String
  }
}

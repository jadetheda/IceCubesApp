import Combine
import Foundation
import Models
import NetworkClient
import OSLog
import Observation

@MainActor
@Observable public class StreamWatcher {
  private var client: FediverseClient?
  private var task: URLSessionWebSocketTask?
  private var watchedStreams: [Stream] = []
  private var instanceStreamingURL: URL?

  private let encoder = JSONEncoder()
  private let streamEventDecoder = StreamEventDecoder()

  private var retryDelay: Int = 10

  public enum Stream: String {
    case federated = "public"
    case local
    case user
    case direct
  }

  public var events: [any StreamEvent] = []
  public var latestEvent: (any StreamEvent)?

  private let logger = Logger(subsystem: "com.icecubesapp", category: "stream")

  public static let shared = StreamWatcher()

  private init() {
  }

  public func setClient(client: FediverseClient, instanceStreamingURL: URL?) {
    if self.client != nil {
      stopWatching()
    }
    self.client = client
    self.instanceStreamingURL = instanceStreamingURL
    Task {
      await streamEventDecoder.setClient(isMisskey: client.isMisskey == true, server: client.server)
    }
    connect()
  }

  private func connect() {
    guard
      let task = try? client?.makeWebSocketTask(
        endpoint: Streaming.streaming,
        instanceStreamingURL: instanceStreamingURL
      )
    else {
      return
    }
    self.task = task
    self.task?.resume()
    receiveMessage()
  }

  public func watch(streams: [Stream]) {
    if client?.isAuth == false {
      return
    }
    if task == nil {
      connect()
    }
    watchedStreams = streams
    for stream in streams {
      if client?.isMisskey == true {
        let channel: String
        switch stream {
        case .user: channel = "homeTimeline"
        case .local: channel = "localTimeline"
        case .federated: channel = "globalTimeline"
        case .direct: channel = "main"
        }
        let message = MisskeyStreamMessage(type: "connect", body: MisskeyStreamMessageBody(channel: channel, id: stream.rawValue))
        sendMisskeyMessage(message: message)
      } else {
        sendMessage(message: StreamMessage(type: "subscribe", stream: stream.rawValue))
      }
    }
  }

  public func stopWatching() {
    task?.cancel()
    task = nil
  }

  private func sendMessage(message: StreamMessage) {
    if let encodedMessage = try? encoder.encode(message),
      let stringMessage = String(data: encodedMessage, encoding: .utf8)
    {
      task?.send(.string(stringMessage), completionHandler: { _ in })
    }
  }

  private func sendMisskeyMessage(message: MisskeyStreamMessage) {
    if let encodedMessage = try? encoder.encode(message),
      let stringMessage = String(data: encodedMessage, encoding: .utf8)
    {
      task?.send(.string(stringMessage), completionHandler: { _ in })
    }
  }

  private func receiveMessage() {
    task?.receive(completionHandler: { [weak self] result in
      guard let self else { return }
      switch result {
      case let .success(message):
        switch message {
        case let .string(string):
          guard let data = string.data(using: .utf8) else {
            logger.error("Error decoding streaming event string")
            return
          }
          let logger = self.logger
          Task { [weak self] in
            guard let self else { return }
            do {
              let decodedEvent = try await streamEventDecoder.decode(data: data)
              if let raw = decodedEvent.rawEvent {
                logger.info("Stream update: \(raw.event)")
              } else {
                logger.info("Stream update: Misskey event")
              }
              await MainActor.run {
                if let event = decodedEvent.event {
                  self.events.append(event)
                  self.latestEvent = event
                }
              }
            } catch let StreamDecodeError.event(rawEvent, error) {
              logger.error("Error decoding streaming event to final event: \(error.localizedDescription)")
              logger.error("Raw data: \(rawEvent.payload)")
            } catch let StreamDecodeError.rawEvent(error) {
              logger.error("Error decoding streaming event: \(error.localizedDescription)")
            } catch {
              logger.error("Unexpected error decoding streaming event: \(error.localizedDescription)")
            }
          }

        default:
          break
        }

        Task { @MainActor in
          self.receiveMessage()
        }

      case .failure:
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(self.retryDelay))
          self.retryDelay += 30
          self.stopWatching()
          self.connect()
          self.watch(streams: self.watchedStreams)
        }
      }
    })
  }

  public func emmitDeleteEvent(for status: String) {
    let event = StreamEventDelete(status: status)
    events.append(event)
    latestEvent = event
  }

  public func emmitEditEvent(for status: Status) {
    let event = StreamEventStatusUpdate(status: status)
    events.append(event)
    latestEvent = event
  }

  public func emmitPostEvent(for status: Status) {
    let event = StreamEventUpdate(status: status)
    events.append(event)
    latestEvent = event
  }
}

fileprivate enum StreamDecodeError: Error {
  case rawEvent(Error)
  case event(rawEvent: RawStreamEvent, error: Error)
}

private actor StreamEventDecoder {
  struct DecodedEvent {
    let rawEvent: RawStreamEvent?
    let event: (any StreamEvent)?
  }

  private var lastTask: Task<DecodedEvent, Error>?
  private var isMisskey: Bool = false
  private var server: String = "misskey"

  func setClient(isMisskey: Bool, server: String) {
    self.isMisskey = isMisskey
    self.server = server
  }

  func decode(data: Data) async throws -> DecodedEvent {
    let previousTask = lastTask
    let isMisskey = self.isMisskey
    let server = self.server
    let task = Task {
      if let previousTask {
        _ = try? await previousTask.value
      }
      return try decodeSequentially(data: data, isMisskey: isMisskey, server: server)
    }
    lastTask = task
    return try await task.value
  }

  private nonisolated func decodeSequentially(data: Data, isMisskey: Bool, server: String) throws -> DecodedEvent {
    let decoder = JSONDecoder()

    if isMisskey {
      return try decodeMisskeyEvent(data: data, decoder: decoder, server: server)
    }

    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let rawEvent: RawStreamEvent
    do {
      rawEvent = try decoder.decode(RawStreamEvent.self, from: data)
    } catch {
      throw StreamDecodeError.rawEvent(error)
    }
    do {
      let event = try decodeEvent(rawEvent: rawEvent, decoder: decoder)
      return DecodedEvent(rawEvent: rawEvent, event: event)
    } catch {
      throw StreamDecodeError.event(rawEvent: rawEvent, error: error)
    }
  }

  private nonisolated func decodeEvent(
    rawEvent: RawStreamEvent,
    decoder: JSONDecoder
  ) throws -> (any StreamEvent)? {
    guard let payloadData = rawEvent.payload.data(using: .utf8) else {
      return nil
    }
    switch rawEvent.event {
    case "update":
      let status = try decoder.decode(Status.self, from: payloadData)
      return StreamEventUpdate(status: status)
    case "status.update":
      let status = try decoder.decode(Status.self, from: payloadData)
      return StreamEventStatusUpdate(status: status)
    case "delete":
      return StreamEventDelete(status: rawEvent.payload)
    case "notification":
      let notification = try decoder.decode(Notification.self, from: payloadData)
      return StreamEventNotification(notification: notification)
    case "conversation":
      let conversation = try decoder.decode(Conversation.self, from: payloadData)
      return StreamEventConversation(conversation: conversation)
    default:
      return nil
    }
  }

  private nonisolated func decodeMisskeyEvent(data: Data, decoder: JSONDecoder, server: String) throws -> DecodedEvent {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String,
          type == "channel",
          let body = json["body"] as? [String: Any],
          let eventType = body["type"] as? String,
          let payload = body["body"] as? [String: Any] else {
        return DecodedEvent(rawEvent: nil, event: nil)
    }
    
    let payloadData = try JSONSerialization.data(withJSONObject: payload)

    switch eventType {
    case "note":
        let note = try decoder.decode(MisskeyNote.self, from: payloadData)
        return DecodedEvent(rawEvent: nil, event: StreamEventUpdate(status: note.toStatus(server: server)))
    case "notification":
        let notification = try decoder.decode(MisskeyNotification.self, from: payloadData)
        if let modelsNotification = notification.toNotification(server: server) {
            return DecodedEvent(rawEvent: nil, event: StreamEventNotification(notification: modelsNotification))
        }
    default:
        break
    }
    return DecodedEvent(rawEvent: nil, event: nil)
  }
}

private struct MisskeyStreamMessage: Encodable {
  let type: String
  let body: MisskeyStreamMessageBody
}

private struct MisskeyStreamMessageBody: Encodable {
  let channel: String
  let id: String
}

import Combine
import Foundation
import Models
import OSLog
import Observation
import SwiftUI
import os

@Observable
public final class FediverseClient: Equatable, Identifiable, Hashable, Sendable {
  public static func == (lhs: FediverseClient, rhs: FediverseClient) -> Bool {
    return lhs.id == rhs.id
  }

  public enum Version: String, Sendable {
    case v1, v2
  }

  public enum ClientError: Error {
    case unexpectedRequest
  }

  public enum OauthError: Error {
    case missingApp
    case invalidRedirectURL
    case requiresNativeLogin
  }

  public var id: String {
    let isAuth = backend.isAuth
    return "\(isAuth)\(server)\(backend.oauthToken?.createdAt ?? 0)"
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public let server: String
  public let version: Version
  
  public let backend: any FediverseBackend
  
  public var isAuth: Bool { backend.isAuth }
  public var isMisskey: Bool { backend is MisskeyBackend }
  public var isIceShrimpWorkaroundsEnabled: Bool { backend.isIceShrimpWorkaroundsEnabled }
  public var oauthToken: OauthToken? { backend.oauthToken }
  public var capabilities: ServerCapabilities { backend.capabilities }



  public init(server: String, version: Version = .v1, oauthToken: OauthToken? = nil, serverSoftware: String = "mastodon") {
    self.server = server
    self.version = version
    
    switch serverSoftware.lowercased() {
    case "iceshrimp":
        self.backend = IceShrimpBackend(server: server, version: version, oauthToken: oauthToken)
    case "misskey":
        self.backend = MisskeyBackend(server: server, version: version, oauthToken: oauthToken)
    
    case "peertube":
        self.backend = PeertubeBackend(server: server, version: version, oauthToken: oauthToken)
    default:
        self.backend = MastodonBackend(server: server, version: version, oauthToken: oauthToken)
    }
  }

  public static func detectServerSoftware(for server: String) async -> String {
    guard let url = URL(string: "https://\(server)/nodeinfo/2.0"),
      let (data, _) = try? await URLSession.shared.data(from: url),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let software = (json["software"] as? [String: Any])?["name"] as? String
    else {
      return "mastodon"
    }

    let name = software.lowercased()
    if name.contains("misskey") || name.contains("firefish") || name.contains("calckey") {
      return "misskey"
    }
    if name.contains("iceshrimp") {
      return "iceshrimp"
    }
    if name.contains("peertube") {
      return "peertube"
    }
    return "mastodon"
  }

  public func oauthURL() async throws -> URL {
    return try await backend.oauthURL()
  }

  public func continueOauthFlow(url: URL) async throws -> OauthToken {
    return try await backend.continueOauthFlow(url: url)
  }

  public func addConnections(_ connections: [String]) { backend.addConnections(connections) }
  public func hasConnection(with url: URL) -> Bool { backend.hasConnection(with: url) }

  public func get<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> Entity {
    return try await backend.get(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func getWithLink<Entity: Decodable>(endpoint: Endpoint) async throws -> (Entity, LinkHandler?) {
    return try await backend.getWithLink(endpoint: endpoint)
  }

  public func post<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> Entity {
    return try await backend.post(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func post(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> HTTPURLResponse? {
    return try await backend.post(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func put<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> Entity {
    return try await backend.put(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func put(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> HTTPURLResponse? {
    return try await backend.put(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func patch<Entity: Decodable>(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> Entity {
    return try await backend.patch(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func patch(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> HTTPURLResponse? {
    return try await backend.patch(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func delete(endpoint: Endpoint, forceVersion: Version? = nil) async throws -> HTTPURLResponse? {
    return try await backend.delete(endpoint: endpoint, forceVersion: forceVersion)
  }

  public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask {
    return try backend.makeWebSocketTask(endpoint: endpoint, instanceStreamingURL: instanceStreamingURL)
  }

  
  public func mediaUpload(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data
  ) async throws -> HTTPURLResponse? {
    return try await backend.mediaUpload(endpoint: endpoint, version: version, method: method, mimeType: mimeType, filename: filename, data: data)
  }

  public func mediaUpload<Entity: Decodable>(
    endpoint: Endpoint,
    version: Version,
    method: String,
    mimeType: String,
    filename: String,
    data: Data
  ) async throws -> Entity {
    return try await backend.mediaUpload(endpoint: endpoint, version: version, method: method, mimeType: mimeType, filename: filename, data: data)
  }
}

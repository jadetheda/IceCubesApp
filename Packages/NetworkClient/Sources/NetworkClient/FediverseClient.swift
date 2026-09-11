import Combine
import Foundation
import Models
import OSLog
import Observation
import SwiftUI
import os

@Observable
public final class FediverseClient: Equatable, Identifiable, Hashable, Sendable {
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

  private static let serverSoftwareCache = ServerSoftwareCache()

  public static func == (lhs: FediverseClient, rhs: FediverseClient) -> Bool {
    return lhs.id == rhs.id
  }

  public enum Version: String, Sendable {
    case v1, v2
  }

  public enum ClientError: Error {
    case unexpectedRequest
    case serverError(statusCode: Int, code: String?, message: String)
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
  public var isPixelfed: Bool { backend is PixelfedBackend }
  public var isIceShrimpWorkaroundsEnabled: Bool { backend.isIceShrimpWorkaroundsEnabled }
  public var oauthToken: OauthToken? { backend.oauthToken }
  public var capabilities: ServerCapabilities { backend.capabilities }



  public init(server: String, version: Version = .v1, oauthToken: OauthToken? = nil, serverSoftware: String = "mastodon") {
    self.server = server
    self.version = version
    
    switch serverSoftware.lowercased() {
    case "pixelfed":
        self.backend = PixelfedBackend(server: server, version: version, oauthToken: oauthToken)
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
    let cacheKey = server.lowercased()
    if let cached = await serverSoftwareCache.value(for: cacheKey) {
      return cached
    }
    
    guard let url = URL(string: "https://\(server)/nodeinfo/2.0") else { return "mastodon" }
    
    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode >= 500 {
            // Server error, do not permanently cache
            return "mastodon"
        } else if httpResponse.statusCode >= 400 {
            await serverSoftwareCache.set("mastodon", for: cacheKey)
            return "mastodon"
        }
      }
      
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let software = (json["software"] as? [String: Any])?["name"] as? String else {
        await serverSoftwareCache.set("mastodon", for: cacheKey)
        return "mastodon"
      }
      
      let name = software.lowercased()
      if name.contains("pixelfed") {
        await serverSoftwareCache.set("pixelfed", for: cacheKey)
        return "pixelfed"
      }
      if name.contains("misskey") || name.contains("firefish") || name.contains("calckey") {
        await serverSoftwareCache.set("misskey", for: cacheKey)
        return "misskey"
      }
      if name.contains("iceshrimp") {
        await serverSoftwareCache.set("iceshrimp", for: cacheKey)
        return "iceshrimp"
      }
      if name.contains("peertube") {
        await serverSoftwareCache.set("peertube", for: cacheKey)
        return "peertube"
      }
      
      await serverSoftwareCache.set("mastodon", for: cacheKey)
      return "mastodon"
      
    } catch {
      // Don't permanently cache a network timeout/failure in memory
      return "mastodon"
    }
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

extension FediverseClient.ClientError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unexpectedRequest:
      "The server does not support this request."
    case let .serverError(statusCode, code, message):
      if let code {
        "Misskey error \(code) (HTTP \(statusCode)): \(message)"
      } else {
        "Misskey error (HTTP \(statusCode)): \(message)"
      }
    }
  }
}

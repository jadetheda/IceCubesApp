import Foundation
import Models

public struct DeepLClient: Sendable {
  public enum DeepLError: Error {
    case notFound
    case missingAPIKey
  }

  private var deeplUserAPIKey: String?
  private var deeplUserAPIFree: Bool

  private var trimmedKey: String {
    (deeplUserAPIKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isFreeEndpoint: Bool {
    if trimmedKey.lowercased().hasSuffix(":fx") {
      return true
    }
    return deeplUserAPIFree
  }

  private func endpointURL(free: Bool) -> URL {
    URL(string: "https://api\(free ? "-free" : "").deepl.com/v2/translate")!
  }

  private var authorizationHeaderValue: String {
    "DeepL-Auth-Key \(trimmedKey)"
  }

  public struct Response: Decodable {
    public struct Translation: Decodable {
      public let detectedSourceLanguage: String
      public let text: String
    }

    public let translations: [Translation]
  }

  private var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  public init(userAPIKey: String?, userAPIFree: Bool) {
    deeplUserAPIKey = userAPIKey
    deeplUserAPIFree = userAPIFree
  }

  private func normalizeTargetLanguage(_ target: String) -> String {
    let normalized = target.replacingOccurrences(of: "_", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    let upper = normalized.uppercased()
    if upper.hasPrefix("ZH") {
      if upper.contains("HANT") || upper.contains("TW") || upper.contains("HK") || upper.contains("MO") {
        return "ZH-HANT"
      }
      return "ZH-HANS"
    }
    if upper == "EN-GB" || upper == "EN-US" || upper == "PT-BR" || upper == "PT-PT" {
      return upper
    }
    if let base = Locale.Language(identifier: normalized).languageCode?.identifier.uppercased(), !base.isEmpty {
      if base == "NO" {
        return "NB"
      }
      return base
    }
    let prefix = String(upper.split(separator: "-").first ?? Substring(upper))
    return prefix.isEmpty ? "EN" : prefix
  }

  private func buildRequest(url: URL, target: String, text: String) -> URLRequest {
    var components = URLComponents()
    components.queryItems = [
      .init(name: "text", value: text),
      .init(name: "target_lang", value: normalizeTargetLanguage(target)),
    ]
    let bodyString = components.percentEncodedQuery ?? ""

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(bodyString.utf8)
    return request
  }

  public func request(
    target: String,
    text: String,
    originalLinks: [HTMLString.Link] = []
  ) async throws -> Translation {
    guard !trimmedKey.isEmpty else {
      throw DeepLError.missingAPIKey
    }
    let primaryFree = isFreeEndpoint
    let primaryRequest = buildRequest(url: endpointURL(free: primaryFree), target: target, text: text)
    var (result, urlResponse) = try await URLSession.shared.data(for: primaryRequest)

    if let httpResponse = urlResponse as? HTTPURLResponse,
       httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
      let alternateRequest = buildRequest(url: endpointURL(free: !primaryFree), target: target, text: text)
      let (altResult, altResponse) = try await URLSession.shared.data(for: alternateRequest)
      if let altHttp = altResponse as? HTTPURLResponse, (200..<300).contains(altHttp.statusCode) {
        result = altResult
      }
    }

    let response = try decoder.decode(Response.self, from: result)
    if let translation = response.translations.first {
      return .init(
        content: translation.text,
        detectedSourceLanguage: translation.detectedSourceLanguage.lowercased(),
        provider: "DeepL.com",
        originalLinks: originalLinks)
    }
    throw DeepLError.notFound
  }
}

import re

with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MastodonBackend.swift', 'r') as f:
    content = f.read()

replacement = '''  public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws
    -> URLSessionWebSocketTask
  {
    let url = try makeURL(
      scheme: "wss", endpoint: endpoint, forceServer: instanceStreamingURL?.host)
    var request = URLRequest(url: url)
    request.setValue("IceCubesApp/1.0", forHTTPHeaderField: "User-Agent")
    if let oauthToken = critical.withLock({ $0.oauthToken }) {
      request.setValue("Bearer \\(oauthToken.accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue(oauthToken.accessToken, forHTTPHeaderField: "Sec-WebSocket-Protocol")
    }
    return urlSession.webSocketTask(with: request)
  }'''

content = re.sub(
    r'  public func makeWebSocketTask\(endpoint: Endpoint, instanceStreamingURL: URL\?\) throws\s*-> URLSessionWebSocketTask\s*\{\s*let url = try makeURL\(\s*scheme: "wss", endpoint: endpoint, forceServer: instanceStreamingURL\?\.host\)\s*var subprotocols: \[String\] = \[\]\s*if let oauthToken = critical\.withLock\(\{ \$0\.oauthToken \}\) \{\s*subprotocols\.append\(oauthToken\.accessToken\)\s*\}\s*return urlSession\.webSocketTask\(with: url, protocols: subprotocols\)\s*\}',
    replacement,
    content
)

with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MastodonBackend.swift', 'w') as f:
    f.write(content)


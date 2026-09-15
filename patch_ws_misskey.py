with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'r') as f:
    content = f.read()

target = '''    public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask {
        // Misskey streaming uses a different protocol; return a task that connects to the
        // Misskey streaming endpoint so it at least doesn't crash.
        let streamingBase = instanceStreamingURL?.absoluteString ?? "wss://\\(server)"
        let wsURL = URL(string: "\\(streamingBase)/streaming") ?? URL(string: "wss://\\(server)/streaming")!
        return URLSession.shared.webSocketTask(with: wsURL)
    }'''

replacement = '''    public func makeWebSocketTask(endpoint: Endpoint, instanceStreamingURL: URL?) throws -> URLSessionWebSocketTask {
        // Misskey streaming uses a different protocol; return a task that connects to the
        // Misskey streaming endpoint so it at least doesn't crash.
        let streamingBase = instanceStreamingURL?.absoluteString ?? "wss://\\(server)"
        let wsURL = URL(string: "\\(streamingBase)/streaming") ?? URL(string: "wss://\\(server)/streaming")!
        var request = URLRequest(url: wsURL)
        request.setValue("IceCubesApp/1.0", forHTTPHeaderField: "User-Agent")
        return URLSession.shared.webSocketTask(with: request)
    }'''

content = content.replace(target, replacement)

with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'w') as f:
    f.write(content)

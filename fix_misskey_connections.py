with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """    public init(server: String, version: FediverseClient.Version = .v1, oauthToken: OauthToken? = nil) {
        self.server = server
        self.version = version
        self.oauthToken = oauthToken
    }

    public func addConnections(_ connections: [String]) {}
    public func hasConnection(with url: URL) -> Bool { false }"""

replacement = """    private let connectionsLock = NSLock()
    private var _connections: Set<String> = []

    public init(server: String, version: FediverseClient.Version = .v1, oauthToken: OauthToken? = nil) {
        self.server = server
        self.version = version
        self.oauthToken = oauthToken
        self._connections = [server]
    }

    public func addConnections(_ connections: [String]) {
        connectionsLock.lock()
        _connections.formUnion(connections)
        connectionsLock.unlock()
    }

    public func hasConnection(with url: URL) -> Bool {
        guard let host = url.host else { return false }
        connectionsLock.lock()
        let cons = _connections
        connectionsLock.unlock()
        
        if let rootHost = host.split(separator: ".", maxSplits: 1).last {
            return cons.contains(host) || cons.contains(String(rootHost)) || host == server || String(rootHost) == server
        } else {
            return cons.contains(host) || host == server
        }
    }"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

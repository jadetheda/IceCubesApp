with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """    public func hasConnection(with url: URL) -> Bool {
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

replacement = """    public func hasConnection(with url: URL) -> Bool {
        guard let host = url.host else { return false }
        connectionsLock.lock()
        let cons = _connections
        connectionsLock.unlock()
        
        if let rootHost = host.split(separator: ".", maxSplits: 1).last {
            if cons.contains(host) || cons.contains(String(rootHost)) || host == server || String(rootHost) == server { return true }
        } else {
            if cons.contains(host) || host == server { return true }
        }
        
        // Misskey's `instance/peers` equivalent is structurally incompatible with Mastodon's, 
        // frequently requiring auth or returning 403s. To ensure cross-instance @mentions 
        // and #tags still route natively in IceCubes, we optimistically accept them here.
        // If the backend search API fails to resolve them later, the router will fallback to Safari.
        if url.lastPathComponent.first == "@" { return true }
        if url.pathComponents.contains(where: { $0 == "tags" || $0 == "tag" }) { return true }
        
        return false
    }"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

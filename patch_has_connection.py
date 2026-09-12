with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """        if let rootHost = host.split(separator: ".", maxSplits: 1).last {
            if cons.contains(host) || cons.contains(String(rootHost)) || host == server || String(rootHost) == server { return true }
        } else {
            if cons.contains(host) || host == server { return true }
        }"""

replacement = """        let lowerHost = host.lowercased()
        let lowerServer = server.lowercased()
        if let rootHost = lowerHost.split(separator: ".", maxSplits: 1).last {
            if cons.contains(lowerHost) || cons.contains(String(rootHost)) || lowerHost == lowerServer || String(rootHost) == lowerServer { return true }
        } else {
            if cons.contains(lowerHost) || lowerHost == lowerServer { return true }
        }"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

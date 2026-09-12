with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()
if 'parts[1].lowercased() != self.server.lowercased()' not in code:
    print("Needs case-insensitive comparison")

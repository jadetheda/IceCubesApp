with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """                        var userParams: [String: Any] = ["username": parts[0]]
                        if parts[1] != self.server {
                            userParams["host"] = parts[1]
                        }
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: userParams),"""

replacement = """                        var userParams: [String: Any] = ["username": parts[0]]
                        if parts[1].lowercased() != self.server.lowercased() {
                            userParams["host"] = parts[1]
                        } else {
                            userParams["host"] = NSNull()
                        }
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: userParams),"""

code = code.replace(target, replacement)

target2 = """                    } else if parts.count == 1 {
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: ["username": parts[0]]),"""

replacement2 = """                    } else if parts.count == 1 {
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: ["username": parts[0], "host": NSNull()]),"""

code = code.replace(target2, replacement2)

with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
    f.write(code)
print("Success")

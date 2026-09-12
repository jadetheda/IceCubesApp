with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """                        let uri = "https://\\(parts[1])/@\\(parts[0])"
                        if let data = try? await makeMisskeyRequest(path: "ap/show", params: ["uri": uri]),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let apType = json["type"] as? String, apType == "User",
                           let object = json["object"] {
                            let objData = try JSONSerialization.data(withJSONObject: object)
                            if let user = try? JSONDecoder().decode(MisskeyUser.self, from: objData) {
                                accounts = [user.toAccount(server: self.server)]
                                resolved = true
                            }
                        }"""

replacement = """                        var userParams: [String: Any] = ["username": parts[0]]
                        if parts[1] != self.server {
                            userParams["host"] = parts[1]
                        }
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: userParams),
                           let user = try? JSONDecoder().decode(MisskeyUser.self, from: data) {
                            accounts = [user.toAccount(server: self.server)]
                            resolved = true
                        }"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

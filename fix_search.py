with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """                if type == "accounts" || type == nil,
                   let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": query]),
                   let users = try? JSONDecoder().decode([MisskeyUser].self, from: data) {
                    accounts = users.map { $0.toAccount() }
                }"""

replacement = """                if type == "accounts" || type == nil {
                    // If looking for a specific user via @username@domain, use users/show to resolve remote users
                    let parts = query.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).components(separatedBy: "@")
                    var resolved = false
                    if parts.count == 2 {
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: ["username": parts[0], "host": parts[1]]),
                           let user = try? JSONDecoder().decode(MisskeyUser.self, from: data) {
                            accounts = [user.toAccount(server: self.server)]
                            resolved = true
                        }
                    } else if parts.count == 1 {
                        if let data = try? await makeMisskeyRequest(path: "users/show", params: ["username": parts[0]]),
                           let user = try? JSONDecoder().decode(MisskeyUser.self, from: data) {
                            accounts = [user.toAccount(server: self.server)]
                            resolved = true
                        }
                    }
                    
                    if !resolved,
                       let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": query]),
                       let users = try? JSONDecoder().decode([MisskeyUser].self, from: data) {
                        accounts = users.map { $0.toAccount(server: self.server) }
                    }
                }"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

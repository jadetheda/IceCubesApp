with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """                        if let data = try? await makeMisskeyRequest(path: "users/show", params: userParams),
                           let user = try? JSONDecoder().decode(MisskeyUser.self, from: data) {
                            accounts = [user.toAccount(server: self.server)]
                            resolved = true
                        }"""

replacement = """                        do {
                            let data = try await makeMisskeyRequest(path: "users/show", params: userParams)
                            let user = try JSONDecoder().decode(MisskeyUser.self, from: data)
                            accounts = [user.toAccount(server: self.server)]
                            resolved = true
                        } catch {
                            let fakeAccount = Account(id: "error1", username: "\\(error.localizedDescription.prefix(50))", displayName: "Error 1", avatar: URL(string: "https://example.com/a.png")!, header: URL(string: "https://example.com/a.png")!, acct: "error@error", note: .init(stringValue: ""), createdAt: ServerDate(), followersCount: 0, followingCount: 0, statusesCount: 0, lastStatusAt: nil, fields: [], locked: false, emojis: [], url: nil, bot: false, discoverable: false)
                            accounts = [fakeAccount]
                            resolved = true
                        }"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

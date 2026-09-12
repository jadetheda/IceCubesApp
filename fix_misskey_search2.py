with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

target = """                    if !resolved,
                       let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": query]),"""

replacement = """                    if !resolved,
                       let data = try? await makeMisskeyRequest(path: "users/search", params: ["query": parts[0]]),"""

if target in code:
    with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "r") as f:
    code = f.read()

code = code.replace('error.localizedDescription.prefix(50)', 'String(describing: error).prefix(100)')

with open("Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift", "w") as f:
    f.write(code)
print("Success")

import re
with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'r') as f:
    text = f.read()

# Replace the trends/statuses mock
replacement = """            } else if path == "trends/statuses" {
                if let data = try? await makeMisskeyRequest(path: "notes/featured", params: params),
                   let notes = try? JSONDecoder().decode([MisskeyNote].self, from: data) {
                    let statuses = notes.map { $0.toStatus() }
                    return statuses as! Entity
                }
                let statuses: [Status] = []
                return statuses as! Entity"""

text = re.sub(r'            \} else if path == "trends/statuses" \{\n                let statuses: \[Status\] = \[\]\n                return statuses as! Entity', replacement, text)

with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MisskeyBackend.swift', 'w') as f:
    f.write(text)


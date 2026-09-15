import re

with open('todo.md', 'r') as f:
    content = f.read()

new_item = "- [ ] **Misskey/Sharkey Streaming API**: Update `StreamWatcher.swift` to support Misskey-style JSON payloads (`{\"type\": \"connect\"}`) and `?i={token}` WebSocket authentication. The app currently maintains the connection to prevent crashes, but true live-streaming of posts/notifications is missing for these servers.\n"

# Insert after the first item in ### Features
match = re.search(r'(### Features\n\n)', content)
if match:
    pos = match.end()
    content = content[:pos] + new_item + content[pos:]
else:
    content += "\n### Features\n\n" + new_item

with open('todo.md', 'w') as f:
    f.write(content)

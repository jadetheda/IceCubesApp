import re

with open('Packages/Account/Sources/Account/Detail/Tabs/RepliesTab.swift', 'r') as f:
    text = f.read()

text = text.replace(
    '      isRemote: account?.url?.host?.lowercased() != client.server.lowercased()\n    )',
    '      isRemote: account?.url?.host?.lowercased() != client.server.lowercased(),\n      supportsGalleryMode: false\n    )'
)

with open('Packages/Account/Sources/Account/Detail/Tabs/RepliesTab.swift', 'w') as f:
    f.write(text)

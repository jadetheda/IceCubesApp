import re

for filename in ['Packages/Account/Sources/Account/Detail/Tabs/StatusesTab.swift', 'Packages/Account/Sources/Account/Detail/Tabs/RepliesTab.swift']:
    with open(filename, 'r') as f:
        text = f.read()
    
    text = text.replace(
        '        isMediaTab: false,',
        '        isMediaTab: false,\n        supportsGalleryMode: false,'
    )
    
    with open(filename, 'w') as f:
        f.write(text)

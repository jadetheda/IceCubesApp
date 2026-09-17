with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'r') as f:
    content = f.read()

if "import Models" not in content:
    content = content.replace("import NetworkClient", "import NetworkClient\nimport Models")

with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'w') as f:
    f.write(content)

import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift", "r") as f:
    content = f.read()

target = """        } else if client.isMisskey || client.isPixelfed {"""
replacement = """        } else if isMisskeyOrPixelfed {"""

prop = """  private var isMisskeyOrPixelfed: Bool {
    client.isMisskey || client.isPixelfed
  }"""

if target in content:
    content = content.replace(target, replacement)
    content = content.replace("  private var shouldShowEditButton: Bool {", prop + "\n\n  private var shouldShowEditButton: Bool {")
    print("Fixed Misskey OR nesting")
    with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift", "w") as f:
        f.write(content)


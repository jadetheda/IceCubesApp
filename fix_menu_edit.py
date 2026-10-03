import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift", "r") as f:
    content = f.read()

target = """        if client.capabilities.supportsStatusEditing && currentInstance.isEditSupported {"""
replacement = """        if shouldShowEditButton {"""

prop = """  private var shouldShowEditButton: Bool {
    client.capabilities.supportsStatusEditing && currentInstance.isEditSupported
  }"""

if target in content:
    content = content.replace(target, replacement)
    content = content.replace("  private func shouldShowRemoteLocalButton(server: String) -> Bool {", prop + "\n\n  private func shouldShowRemoteLocalButton(server: String) -> Bool {")
    print("Fixed edit button nesting")
    with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift", "w") as f:
        f.write(content)


import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift", "r") as f:
    content = f.read()

target = """        isStandalone: isStandaloneOverride || attachments.count == 1,"""
replacement = """        isStandalone: calculateIsStandalone(isStandaloneOverride: isStandaloneOverride, attachmentsCount: attachments.count),"""

func = """  }
  
  private func calculateIsStandalone(isStandaloneOverride: Bool, attachmentsCount: Int) -> Bool {
    isStandaloneOverride || attachmentsCount == 1
  }

  var body: some View {"""

if target in content:
    content = content.replace(target, replacement)
    content = content.replace("  }\n\n  var body: some View {", func)
    print("Fixed isStandalone")

with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift", "w") as f:
    f.write(content)

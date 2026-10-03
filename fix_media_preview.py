import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift", "r") as f:
    content = f.read()

target1 = """} else if userPreferences.statusMediaGridMode && attachments.count <= 4 {"""
replacement1 = """} else if useMediaGridMode {"""

prop1 = """  var useMediaGridMode: Bool {
    userPreferences.statusMediaGridMode && attachments.count <= 4
  }"""

target2 = """fallbackUrl: displayData.previewFallbackUrl ?? displayData.fallbackUrl"""
replacement2 = """fallbackUrl: displayData.safeFallbackUrl"""

prop2 = """  var previewFallbackUrl: URL?
  
  var safeFallbackUrl: URL? {
    previewFallbackUrl ?? fallbackUrl
  }"""

if target1 in content:
    content = content.replace(target1, replacement1)
    content = content.replace("  var effectiveUseRemoteMedia: Bool {", prop1 + "\n\n  var effectiveUseRemoteMedia: Bool {")
    print("Fixed grid condition")

if "fallbackUrl: displayData.previewFallbackUrl ?? displayData.fallbackUrl" in content:
    content = content.replace("fallbackUrl: displayData.previewFallbackUrl ?? displayData.fallbackUrl", replacement2)
    content = content.replace("  var previewFallbackUrl: URL?", prop2)
    print("Fixed fallback coalescing")

if "fallbackUrl: data.previewFallbackUrl ?? data.fallbackUrl" in content:
    content = content.replace("fallbackUrl: data.previewFallbackUrl ?? data.fallbackUrl", "fallbackUrl: data.safeFallbackUrl")
    print("Fixed fallback coalescing 2")

with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift", "w") as f:
    f.write(content)

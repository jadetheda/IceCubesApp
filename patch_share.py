import re

# ShareToolbarItem.swift
with open('Packages/MediaUI/Sources/MediaUI/ShareToolbarItem.swift', 'r') as f:
    content = f.read()
content = content.replace("let url: URL\n  let type: DisplayType", "let url: URL\n  let fallbackUrl: URL? = nil\n  let type: DisplayType")
content = content.replace("MediaUIShareLink(url: url, type: type)", "MediaUIShareLink(url: url, fallbackUrl: fallbackUrl, type: type)")
with open('Packages/MediaUI/Sources/MediaUI/ShareToolbarItem.swift', 'w') as f:
    f.write(content)

# MediaUIShareLink.swift
with open('Packages/MediaUI/Sources/MediaUI/MediaUIShareLink.swift', 'r') as f:
    content = f.read()
content = content.replace("let url: URL\n  let type: DisplayType", "let url: URL\n  let fallbackUrl: URL? = nil\n  let type: DisplayType")
content = content.replace("public init(url: URL, type: DisplayType)", "public init(url: URL, fallbackUrl: URL? = nil, type: DisplayType)")
content = content.replace("self.url = url\n    self.type = type", "self.url = url\n    self.fallbackUrl = fallbackUrl\n    self.type = type")
content = content.replace("let transferable = MediaUIImageTransferable(url: url)", "let transferable = MediaUIImageTransferable(url: url, fallbackUrl: fallbackUrl)")
# wait! the second branch is ShareLink(item: url)
content = content.replace("ShareLink(item: url)", "ShareLink(item: fallbackUrl ?? url)")
with open('Packages/MediaUI/Sources/MediaUI/MediaUIShareLink.swift', 'w') as f:
    f.write(content)

# MediaUITransferableImage.swift
with open('Packages/MediaUI/Sources/MediaUI/MediaUITransferableImage.swift', 'r') as f:
    content = f.read()
content = content.replace("public let url: URL", "public let url: URL\n  public let fallbackUrl: URL?")

# Need to update init
# Currently: public init(url: URL) { self.url = url }
content = content.replace("public init(url: URL) {", "public init(url: URL, fallbackUrl: URL? = nil) {")
content = content.replace("self.url = url\n  }", "self.url = url\n    self.fallbackUrl = fallbackUrl\n  }")

# In transferRepresentation, we need to check both URLs for cache
new_representation = """
        var data = ImagePipeline.shared.cache.cachedData(for: .init(url: transferable.url))?.data
        if data == nil, let fallbackUrl = transferable.fallbackUrl {
            data = ImagePipeline.shared.cache.cachedData(for: .init(url: fallbackUrl))?.data
        }
        if data == nil {
            data = try? await URLSession.shared.data(from: transferable.url).0
        }
        if data == nil, let fallbackUrl = transferable.fallbackUrl {
            data = try? await URLSession.shared.data(from: fallbackUrl).0
        }
        if let data {
"""
content = re.sub(r'if let data = ImagePipeline\.shared\.cache\.cachedData.*?\{', new_representation.strip() + " {", content, flags=re.DOTALL)

with open('Packages/MediaUI/Sources/MediaUI/MediaUITransferableImage.swift', 'w') as f:
    f.write(content)


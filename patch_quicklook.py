import re

with open('Packages/MediaUI/Sources/MediaUI/QuickLookToolbarItem.swift', 'r') as f:
    content = f.read()

content = content.replace("let itemUrl: URL", "let itemUrl: URL\n  let fallbackUrl: URL? = nil")
content = content.replace("localPath = await localPathFor(url: itemUrl)", "localPath = await localPathFor(url: itemUrl, fallbackUrl: fallbackUrl)")
content = content.replace("private func imageData(_ url: URL) async -> Data?", "private func imageData(_ url: URL, fallbackUrl: URL?) async -> Data?")

new_imagedata = """
    var data = ImagePipeline.shared.cache.cachedData(for: .init(url: url))
    if data == nil, let fallbackUrl {
      data = ImagePipeline.shared.cache.cachedData(for: .init(url: fallbackUrl))
    }
    if data == nil {
      data = try? await URLSession.shared.data(from: url).0
    }
    if data == nil, let fallbackUrl {
      data = try? await URLSession.shared.data(from: fallbackUrl).0
    }
    return data
"""

content = re.sub(r'    var data = ImagePipeline\.shared\.cache\.cachedData.*?return data', new_imagedata.strip(), content, flags=re.DOTALL)
content = content.replace("private func localPathFor(url: URL) async -> URL {", "private func localPathFor(url: URL, fallbackUrl: URL?) async -> URL {")
content = content.replace("let data = await imageData(url)", "let data = await imageData(url, fallbackUrl: fallbackUrl)")

with open('Packages/MediaUI/Sources/MediaUI/QuickLookToolbarItem.swift', 'w') as f:
    f.write(content)

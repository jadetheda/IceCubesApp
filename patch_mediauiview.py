import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'r') as f:
    content = f.read()

content = content.replace("QuickLookToolbarItem(itemUrl: data.url)", "QuickLookToolbarItem(itemUrl: data.url, fallbackUrl: data.fallbackUrl)")
content = content.replace("SavePhotoToolbarItem(url: data.url, type: data.type)", "SavePhotoToolbarItem(url: data.url, fallbackUrl: data.fallbackUrl, type: data.type)")
content = content.replace("ShareToolbarItem(url: data.url, type: data.type)", "ShareToolbarItem(url: data.url, fallbackUrl: data.fallbackUrl, type: data.type)")

content = content.replace("let url: URL\n  let type: DisplayType", "let url: URL\n  let fallbackUrl: URL?\n  let type: DisplayType")
content = content.replace("if await saveImage(url: url) {", "if await saveImage(url: url, fallbackUrl: fallbackUrl) {")

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

content = content.replace("private func uiimageFor(url: URL) async throws -> UIImage?", "private func uiimageFor(url: URL, fallbackUrl: URL?) async throws -> UIImage?")
content = content.replace("let data = await imageData(url)", "let data = await imageData(url, fallbackUrl: fallbackUrl)")

content = content.replace("private func saveImage(url: URL) async -> Bool", "private func saveImage(url: URL, fallbackUrl: URL?) async -> Bool")
content = content.replace("guard let image = try? await uiimageFor(url: url)", "guard let image = try? await uiimageFor(url: url, fallbackUrl: fallbackUrl)")


with open('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'w') as f:
    f.write(content)

with open('Packages/MediaUI/Sources/MediaUI/MediaUITransferableImage.swift', 'r') as f:
    content = f.read()

new_fetch = """
  public func fetchData() async -> Data {
    do {
      let data = try await URLSession.shared.data(from: url).0
      return data
    } catch {
      if let fallbackUrl, let fallbackData = try? await URLSession.shared.data(from: fallbackUrl).0 {
          return fallbackData
      }
      return Data()
    }
  }
"""
import re
content = re.sub(r'  public func fetchData\(\) async -> Data \{.*?^\s*\}', new_fetch.strip(), content, flags=re.DOTALL|re.MULTILINE)
with open('Packages/MediaUI/Sources/MediaUI/MediaUITransferableImage.swift', 'w') as f:
    f.write(content)

import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'r') as f:
    content = f.read()

new_save = """
  private func saveImage(url: URL, fallbackUrl: URL?) async -> Bool {
    guard let data = await imageData(url, fallbackUrl: fallbackUrl) else { return false }

    var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

    if status != .authorized {
      await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    if status == .authorized {
      return await withCheckedContinuation { continuation in
        PHPhotoLibrary.shared().performChanges({
          let request = PHAssetCreationRequest.forAsset()
          request.addResource(with: .photo, data: data, options: nil)
        }) { success, _ in
          continuation.resume(returning: success)
        }
      }
    }
    return false
  }
"""

content = re.sub(r'  private func saveImage\(url: URL, fallbackUrl: URL\?\) async -> Bool \{.*?return false\n  \}', new_save.strip(), content, flags=re.DOTALL)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'w') as f:
    f.write(content)

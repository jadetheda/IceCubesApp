with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'r') as f:
    content = f.read()

if "import Photos" not in content:
    content = content.replace("import SwiftUI", "import SwiftUI\nimport Photos\nimport Models")

button_code = """
        Button {
          isShareAsImageSheetPresented = true
        } label: {
          Label("status.action.share-image", systemImage: "photo")
        }

        let imageAttachments = (viewModel.status.mediaAttachments.isEmpty ? (viewModel.status.reblog?.mediaAttachments ?? []) : viewModel.status.mediaAttachments).filter { $0.supportedType == .image }
        if imageAttachments.count > 1 {
          Button {
            Task {
              await downloadAllImages(attachments: imageAttachments)
            }
          } label: {
            Label("status.action.download-all-images", systemImage: "square.and.arrow.down.on.square")
          }
        }
"""
content = content.replace("""        Button {
          isShareAsImageSheetPresented = true
        } label: {
          Label("status.action.share-image", systemImage: "photo")
        }""", button_code.strip())

func_code = """
  private func downloadAllImages(attachments: [Models.MediaAttachment]) async {
    for attachment in attachments {
      guard let info = attachment.displayInfo(useRemoteMedia: preferences.remoteMediaAlwaysForce, fallbackOnFail: preferences.remoteMediaFallbackOnFail, neverLoadVideo: false) else { continue }
      
      var data: Data? = nil
      data = try? await URLSession.shared.data(from: info.url).0
      if data == nil, let fallbackUrl = info.fallbackUrl {
        data = try? await URLSession.shared.data(from: fallbackUrl).0
      }
      
      if let data {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status != .authorized {
          status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        if status == .authorized {
          do {
            try await PHPhotoLibrary.shared().performChanges {
              let request = PHAssetCreationRequest.forAsset()
              request.addResource(with: .photo, data: data, options: nil)
            }
          } catch {
            print(error)
          }
        }
      }
    }
  }
"""

content = content.rsplit("  }\n}", 1)[0] + "  }\n\n" + func_code + "\n}\n"

with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'w') as f:
    f.write(content)

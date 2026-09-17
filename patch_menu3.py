with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'r') as f:
    content = f.read()

# Replace computed property
old_prop = """  var imageAttachments: [Models.MediaAttachment] {
    (viewModel.status.mediaAttachments.isEmpty ? (viewModel.status.reblog?.mediaAttachments ?? []) : viewModel.status.mediaAttachments).filter { $0.supportedType == .image }
  }"""
new_prop = """  var downloadableMedia: [Models.MediaAttachment] {
    (viewModel.status.mediaAttachments.isEmpty ? (viewModel.status.reblog?.mediaAttachments ?? []) : viewModel.status.mediaAttachments).filter { $0.supportedType == .image || $0.supportedType == .video || $0.supportedType == .gifv }
  }"""
content = content.replace(old_prop, new_prop)

# Replace the Menu button injection
old_button = """        if imageAttachments.count > 1 {
          Button {
            Task {
              await downloadAllImages(attachments: imageAttachments)
            }
          } label: {
            Label("status.action.download-all-images", systemImage: "square.and.arrow.down.on.square")
          }
        }"""
new_button = """        if downloadableMedia.count > 0 {
          Button {
            Task {
              await downloadAllMedia(attachments: downloadableMedia)
            }
          } label: {
            Label(downloadableMedia.count > 1 ? "status.action.download-all-media" : "status.action.download-media", systemImage: "square.and.arrow.down.on.square")
          }
        }"""
content = content.replace(old_button, new_button)

# Replace the function
old_func = """  private func downloadAllImages(attachments: [Models.MediaAttachment]) async {
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
  }"""
new_func = """  private func downloadAllMedia(attachments: [Models.MediaAttachment]) async {
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
              let resourceType: PHAssetResourceType = (attachment.supportedType == .video || attachment.supportedType == .gifv) ? .video : .photo
              request.addResource(with: resourceType, data: data, options: nil)
            }
          } catch {
            print(error)
          }
        }
      }
    }
  }"""
content = content.replace(old_func, new_func)

with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'w') as f:
    f.write(content)

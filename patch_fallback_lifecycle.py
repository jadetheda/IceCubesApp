import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'r') as f:
    content = f.read()

old_prepare = """  func preparePlayer(autoPlay: Bool, isCompact: Bool, loopVideo: Bool) {
    let asset: AVURLAsset
    if url.pathExtension.isEmpty || url.pathExtension.lowercased() == "gif" {
      asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "video/mp4"])
    } else {
      asset = AVURLAsset(url: url)
    }"""

new_prepare = """  func preparePlayer(autoPlay: Bool, isCompact: Bool, loopVideo: Bool) {
    let asset: AVURLAsset
    let activeUrl = (hasFalledBack && fallbackUrl != nil) ? fallbackUrl! : url
    if activeUrl.pathExtension.isEmpty || activeUrl.pathExtension.lowercased() == "gif" {
      asset = AVURLAsset(url: activeUrl, options: ["AVURLAssetOutOfBandMIMETypeKey": "video/mp4"])
    } else {
      asset = AVURLAsset(url: activeUrl)
    }"""

content = content.replace(old_prepare, new_prepare)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'w') as f:
    f.write(content)

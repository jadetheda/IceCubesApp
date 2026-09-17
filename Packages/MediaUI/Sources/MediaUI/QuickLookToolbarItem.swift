import Nuke
import NukeUI
import SwiftUI

struct QuickLookToolbarItem: ToolbarContent, @unchecked Sendable {
  let itemUrl: URL
  var fallbackUrl: URL? = nil
  @State private var localPath: URL?
  @State private var isLoading = false

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        Task {
          isLoading = true
          localPath = await localPathFor(url: itemUrl, fallbackUrl: fallbackUrl)
          isLoading = false
        }
      } label: {
        if isLoading {
          ProgressView()
        } else {
          Image(systemName: "info.circle")
        }
      }
      .quickLookPreview($localPath)
    }
  }

  private func imageData(_ url: URL, fallbackUrl: URL?) async -> Data? {
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
  }

  private func localPathFor(url: URL, fallbackUrl: URL?) async -> URL {
    try? FileManager.default.removeItem(at: quickLookDir)
    try? FileManager.default.createDirectory(at: quickLookDir, withIntermediateDirectories: true)
    let path = quickLookDir.appendingPathComponent(url.lastPathComponent)
    let data = await imageData(url, fallbackUrl: fallbackUrl)
    try? data?.write(to: path)
    return path
  }

  private var quickLookDir: URL {
    try! FileManager.default.url(
      for: .cachesDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
    .appending(component: "quicklook")
  }
}

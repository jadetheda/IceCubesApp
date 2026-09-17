import CoreTransferable
import SwiftUI
import UIKit

public struct MediaUIImageTransferable: Codable, Transferable {
  public let url: URL
  public let fallbackUrl: URL?

  public init(url: URL, fallbackUrl: URL? = nil) {
    self.url = url
    self.fallbackUrl = fallbackUrl
  }

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

  public static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .jpeg) { transferable in
      await transferable.fetchData()
    }
  }
}

import Combine
import Models
import QuickLook
import SwiftUI

@MainActor
@Observable public class QuickLook {
  public var selectedMediaAttachment: MediaAttachment?
  public var mediaAttachments: [MediaAttachment] = []
  public var useRemoteMedia: Bool = false
  
  @ObservationIgnored
  public var namespace: Namespace.ID?

  public static let shared = QuickLook()

  private init() {}

  public func prepareFor(
    selectedMediaAttachment: MediaAttachment, mediaAttachments: [MediaAttachment], useRemoteMedia: Bool = false
  ) {
    self.selectedMediaAttachment = selectedMediaAttachment
    self.mediaAttachments = mediaAttachments
    self.useRemoteMedia = useRemoteMedia
  }
}

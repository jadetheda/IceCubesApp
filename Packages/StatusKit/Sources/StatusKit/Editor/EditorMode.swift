import Models
import SwiftUI
import UIKit

extension StatusEditor.EditorStore {
  public enum Mode {
    case replyTo(status: Status)
    case new(text: String?, visibility: Models.Visibility)
    case edit(status: Status)
    case redraft(status: Status)
    case quote(status: Status)
    case quoteLink(link: URL)
    case mention(account: Account, visibility: Models.Visibility)
    case shareExtension(items: [NSItemProvider])
    case imageURL(urls: [URL], caption: String?, altTexts: [String]?, visibility: Models.Visibility)

    var isInShareExtension: Bool {
      switch self {
      case .shareExtension:
        true
      default:
        false
      }
    }

    var isEditing: Bool {
      switch self {
      case .edit:
        true
      default:
        false
      }
    }

    var isRedrafting: Bool {
      switch self {
      case .redraft:
        true
      default:
        false
      }
    }

    var replyToStatus: Status? {
      switch self {
      case let .replyTo(status):
        status
      default:
        nil
      }
    }

    var redraftStatus: Status? {
      switch self {
      case let .redraft(status):
        status
      default:
        nil
      }
    }

    var inReplyToStatusId: String? {
      switch self {
      case let .replyTo(status):
        status.id
      case let .redraft(status):
        status.inReplyToId
      default:
        nil
      }
    }

    var title: LocalizedStringKey {
      switch self {
      case .new, .mention, .shareExtension, .quoteLink, .imageURL, .redraft:
        "status.editor.mode.new"
      case .edit:
        "status.editor.mode.edit"
      case let .replyTo(status):
        "status.editor.mode.reply-\(status.reblog?.account.displayNameWithoutEmojis ?? status.account.displayNameWithoutEmojis)"
      case let .quote(status):
        "status.editor.mode.quote-\(status.reblog?.account.displayNameWithoutEmojis ?? status.account.displayNameWithoutEmojis)"
      }
    }
  }
}

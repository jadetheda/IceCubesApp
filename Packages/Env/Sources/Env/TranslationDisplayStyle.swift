import Foundation
import SwiftUI

public enum TranslationDisplayStyle: String, CaseIterable, Sendable, Codable {
  case card
  case inline

  public var description: LocalizedStringKey {
    switch self {
    case .card:
      "Card"
    case .inline:
      "Inline"
    }
  }
}

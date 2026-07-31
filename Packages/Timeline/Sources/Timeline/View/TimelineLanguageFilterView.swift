import DesignSystem
import Env
import Models
import SwiftUI

@MainActor
public struct TimelineLanguageFilterView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var contentFilter = TimelineContentFilter.shared
  @State private var languageSearch: String = ""

  public init() {}

  public var body: some View {
    Form {
      Section {
        ForEach(languageSearchResult(query: languageSearch)) { language in
          Toggle(isOn: Binding(
            get: { contentFilter.hiddenLanguages.contains(language.isoCode) },
            set: { isHidden in
              if isHidden {
                contentFilter.hiddenLanguages.append(language.isoCode)
              } else {
                contentFilter.hiddenLanguages.removeAll(where: { $0 == language.isoCode })
              }
            }
          )) {
            HStack {
              if let nativeName = language.nativeName {
                Text(nativeName)
              } else {
                Text(language.localizedName ?? language.isoCode)
              }
              if let localizedName = language.localizedName, language.nativeName != nil {
                Text(localizedName)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    }
    .searchable(text: $languageSearch, placement: .navigationBarDrawer)
    .navigationTitle("status.editor.language-select.navigation-title")
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          dismiss()
        } label: {
          Text("action.done").bold()
        }
      }
    }
  }

  private func languageSearchResult(query: String) -> [Language] {
    if query.isEmpty {
      return Language.allAvailableLanguages
    }
    return Language.allAvailableLanguages.filter { language in
      language.nativeName?.lowercased().hasPrefix(query.lowercased()) == true
        || language.localizedName?.lowercased().hasPrefix(query.lowercased()) == true
        || language.isoCode.lowercased().hasPrefix(query.lowercased()) == true
    }
  }
}

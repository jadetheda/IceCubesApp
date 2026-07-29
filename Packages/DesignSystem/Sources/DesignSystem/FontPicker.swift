import Env
import SwiftUI
import UniformTypeIdentifiers

struct SystemFontPicker: UIViewControllerRepresentable {
  @Environment(\.dismiss) var dismiss

  class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
    private let dismiss: DismissAction

    init(dismiss: DismissAction) {
      self.dismiss = dismiss
    }

    func fontPickerViewControllerDidCancel(_: UIFontPickerViewController) {
      dismiss()
    }

    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
      Theme.shared.chosenFont = UIFont(descriptor: viewController.selectedFontDescriptor!, size: 0)
      dismiss()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(dismiss: dismiss)
  }

  func makeUIViewController(context: Context) -> UIFontPickerViewController {
    let controller = UIFontPickerViewController()
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_: UIFontPickerViewController, context _: Context) {}
}

public struct FontPicker: View {
  @Environment(\.dismiss) var dismiss
  @State private var searchText = ""
  @State private var customFontName = ""
  @State private var showSystemPicker = false
  @State private var showFileImporter = false
  @State private var importedFonts: [String] = []

  @State private var availableFonts: [String] = {
    var names: [String] = []
    for family in UIFont.familyNames.sorted() {
      let fontNames = UIFont.fontNames(forFamilyName: family)
      if fontNames.isEmpty {
        names.append(family)
      } else {
        names.append(contentsOf: fontNames.sorted())
      }
    }
    return Array(Set(names)).sorted()
  }()

  var filteredFonts: [String] {
    if searchText.isEmpty {
      return availableFonts
    } else {
      return availableFonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
  }

  public init() {}

  public var body: some View {
    List {
      Section {
        Button {
          showFileImporter = true
        } label: {
          HStack {
            Label("Import Font File (.ttf / .otf)", systemImage: "square.and.arrow.down")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "plus")
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        }

        if !importedFonts.isEmpty {
          ForEach(importedFonts, id: \.self) { fontName in
            HStack {
              Button {
                Theme.shared.chosenFont = UIFont(name: fontName, size: 17)
                dismiss()
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(fontName)
                    .font(.custom(fontName, size: 17))
                    .foregroundColor(.primary)
                  Text("Sample Text - 123")
                    .font(.custom(fontName, size: 13))
                    .foregroundColor(.secondary)
                }
              }
              Spacer()
              if Theme.shared.chosenFont?.fontName == fontName {
                Image(systemName: "checkmark")
                  .foregroundColor(.blue)
              }
              Button(role: .destructive) {
                Theme.shared.deleteImportedFont(name: fontName)
                importedFonts = Theme.shared.getImportedFonts()
                if Theme.shared.chosenFont?.fontName == fontName {
                  Theme.shared.chosenFont = nil
                }
              } label: {
                Image(systemName: "trash")
                  .foregroundColor(.red)
              }
              .buttonStyle(.borderless)
            }
          }
        }
      } header: {
        Text("Imported Fonts")
      } footer: {
        Text("Download any .ttf or .otf font file to your device, then tap Import to make it available in Ice Cubes.")
      }

      Section {
        HStack {
          TextField("Type custom font name (e.g. FiraCode-Regular)", text: $customFontName)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.none)

          Button("Apply") {
            if !customFontName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              if let font = UIFont(name: customFontName, size: 17) {
                Theme.shared.chosenFont = font
                dismiss()
              } else {
                Theme.shared.chosenFont = UIFont(name: customFontName, size: 17) ?? .systemFont(ofSize: 17)
                dismiss()
              }
            }
          }
          .disabled(customFontName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      } header: {
        Text("Custom Font Name")
      } footer: {
        Text("Enter the exact PostScript name of any installed font.")
      }

      Section {
        Button {
          showSystemPicker = true
        } label: {
          HStack {
            Label("Open iOS System Font Picker", systemImage: "textformat")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        }
      } header: {
        Text("System Font Picker")
      }

      Section {
        ForEach(filteredFonts, id: \.self) { fontName in
          Button {
            Theme.shared.chosenFont = UIFont(name: fontName, size: 17)
            dismiss()
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(fontName)
                  .font(.custom(fontName, size: 17))
                  .foregroundColor(.primary)
                Text("Sample Text - 123")
                  .font(.custom(fontName, size: 13))
                  .foregroundColor(.secondary)
              }
              Spacer()
              if Theme.shared.chosenFont?.fontName == fontName {
                Image(systemName: "checkmark")
                  .foregroundColor(.blue)
              }
            }
          }
        }
      } header: {
        Text("All Installed Fonts (\(filteredFonts.count))")
      }
    }
    .searchable(text: $searchText, prompt: "Search fonts...")
    .navigationTitle("Font Selector")
    .sheet(isPresented: $showSystemPicker) {
      SystemFontPicker()
    }
    .onAppear {
      importedFonts = Theme.shared.getImportedFonts()
    }
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: [
        .font,
        UTType(filenameExtension: "ttf") ?? .font,
        UTType(filenameExtension: "otf") ?? .font,
        UTType(mimeType: "font/otf") ?? .font,
        UTType(mimeType: "font/ttf") ?? .font,
        .data,
        .item,
        .content
      ],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        guard let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer {
          if access {
            url.stopAccessingSecurityScopedResource()
          }
        }
        if let postScriptName = Theme.shared.importFont(from: url) {
          Theme.shared.chosenFont = UIFont(name: postScriptName, size: 17)
          importedFonts = Theme.shared.getImportedFonts()
        }
      case .failure(let error):
        print("File selection failed: \(error)")
      }
    }
  }
}

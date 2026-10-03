with open("Packages/StatusKit/Sources/StatusKit/Row/StatusRowView.swift", "r") as f:
    content = f.read()

target = """    .onAppear {
      if !reasons.contains(.placeholder) {
        if !isCompact {
          if viewModel.embeddedStatus == nil {
            Task {
              await viewModel.loadEmbeddedStatus()
            }
          }
        }
      }
    }
    .task {
      if !reasons.contains(.placeholder) {
        if UserPreferences.shared.pluraldawnSupportEnabled {
          await viewModel.fetchPluraldawnSystemIfNeeded()
        }
      }
    }"""

replacement = """    .onAppear {
      if !reasons.contains(.placeholder) {
        if !isCompact {
          if viewModel.embeddedStatus == nil {
            Task {
              await viewModel.loadEmbeddedStatus()
            }
          }
        }
        if UserPreferences.shared.pluraldawnSupportEnabled {
          Task {
            await viewModel.fetchPluraldawnSystemIfNeeded()
          }
        }
      }
    }"""

if target in content:
    content = content.replace(target, replacement)
    with open("Packages/StatusKit/Sources/StatusKit/Row/StatusRowView.swift", "w") as f:
        f.write(content)
    print("Success")
else:
    print("Target not found")

const fs = require('fs');
let content = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/Row/StatusRowView.swift', 'utf-8');

const target = `    .onAppear {
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
    }`;

const replacement = `    .onAppear {
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
    }`;

if (content.includes(target)) {
    content = content.replace(target, replacement);
    fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/Row/StatusRowView.swift', content, 'utf-8');
    console.log("Success");
} else {
    console.log("Target not found");
}

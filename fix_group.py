import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowHeaderView.swift", "r") as f:
    content = f.read()

target = """    } else {
      Group {
        Text(Image(systemName: viewModel.finalStatus.visibility.iconName)) + Text(" ⸱ ") + Text(viewModel.finalStatus.createdAt.relativeFormatted)
      }
      .fixedSize(horizontal: false, vertical: true)
      .font(.scaledFootnote)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    }"""

replacement = """    } else {
      HStack(spacing: 4) {
        Image(systemName: viewModel.finalStatus.visibility.iconName)
        Text("⸱")
        Text(viewModel.finalStatus.createdAt.relativeFormatted)
      }
      .fixedSize(horizontal: false, vertical: true)
      .font(.scaledFootnote)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    }"""

if target in content:
    content = content.replace(target, replacement)
    print("Fixed Group + Text concatenation")
    with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowHeaderView.swift", "w") as f:
        f.write(content)


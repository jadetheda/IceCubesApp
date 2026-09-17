with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'r') as f:
    content = f.read()

# Replace the inline let statement with just the if block
inline_code = """        let imageAttachments = (viewModel.status.mediaAttachments.isEmpty ? (viewModel.status.reblog?.mediaAttachments ?? []) : viewModel.status.mediaAttachments).filter { $0.supportedType == .image }
        if imageAttachments.count > 1 {"""

content = content.replace(inline_code, "        if imageAttachments.count > 1 {")

# Add the computed property
computed_prop = """  var imageAttachments: [Models.MediaAttachment] {
    (viewModel.status.mediaAttachments.isEmpty ? (viewModel.status.reblog?.mediaAttachments ?? []) : viewModel.status.mediaAttachments).filter { $0.supportedType == .image }
  }

  var viewModel: StatusRowViewModel"""

content = content.replace("  var viewModel: StatusRowViewModel", computed_prop)

with open('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift', 'w') as f:
    f.write(content)

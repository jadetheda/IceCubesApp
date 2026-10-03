import re
with open("Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift", "r") as f:
    content = f.read()

target1 = """      .sheet(isPresented: $showSelectableText) {
        if let viewModel {
          StatusRowSelectableTextView(
            content: viewModel.status.reblog?.content.asSafeMarkdownAttributedString
              ?? viewModel.status.content.asSafeMarkdownAttributedString
          )
        }
      }"""
replacement1 = """      .sheet(isPresented: $showSelectableText) {
        if let viewModel {
          let reblogContent = viewModel.status.reblog?.content.asSafeMarkdownAttributedString
          let statusContent = viewModel.status.content.asSafeMarkdownAttributedString
          let contentStr = reblogContent ?? statusContent
          StatusRowSelectableTextView(
            content: contentStr
          )
        }
      }"""

target2 = """                let operationAccount = viewModel.status.reblog?.account ?? viewModel.status.account
                viewModel.authorRelationship = try await client.post(
                  endpoint: Accounts.block(id: operationAccount.id))"""
replacement2 = """                let reblogAcct = viewModel.status.reblog?.account
                let acct = viewModel.status.account
                let operationAccount = reblogAcct ?? acct
                viewModel.authorRelationship = try await client.post(
                  endpoint: Accounts.block(id: operationAccount.id))"""

if target1 in content:
    content = content.replace(target1, replacement1)
    print("Fixed target1")
if target2 in content:
    content = content.replace(target2, replacement2)
    print("Fixed target2")

with open("Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift", "w") as f:
    f.write(content)

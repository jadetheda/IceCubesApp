import re

# 1. StatusRowSwipeView.swift
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowSwipeView.swift", "r") as f:
    content = f.read()

# Fix comma-separated ifs
content = content.replace("if preferences.swipeActionsStatusTrailingRight != StatusAction.none, !viewModel.isRemote {", "if preferences.swipeActionsStatusTrailingRight != StatusAction.none {\nif !viewModel.isRemote {")
content = content.replace("if preferences.swipeActionsStatusTrailingLeft != StatusAction.none, !viewModel.isRemote {", "if preferences.swipeActionsStatusTrailingLeft != StatusAction.none {\nif !viewModel.isRemote {")
content = content.replace("if preferences.swipeActionsStatusLeadingLeft != StatusAction.none, !viewModel.isRemote {", "if preferences.swipeActionsStatusLeadingLeft != StatusAction.none {\nif !viewModel.isRemote {")
content = content.replace("if preferences.swipeActionsStatusLeadingRight != StatusAction.none, !viewModel.isRemote {", "if preferences.swipeActionsStatusLeadingRight != StatusAction.none {\nif !viewModel.isRemote {")
# Need to add closing braces for the new ifs. Actually, it's easier to just use `&&` or extract them. Wait, `AGENTS.md` says chained logic is bad, but nested ifs are good.
# Let's extract the disabled logic
disabled_target = """        .disabled(
          viewModel.status.visibility == .direct
            || viewModel.status.visibility == .priv
              && viewModel.status.account.id != currentAccount.account?.id
        )"""
disabled_repl = """        .disabled(isBoostDisabled())"""
if disabled_target in content:
    content = content.replace(disabled_target, disabled_repl)
    
prop = """  private func isBoostDisabled() -> Bool {
    if viewModel.status.visibility == .direct { return true }
    if viewModel.status.visibility == .priv && viewModel.status.account.id != currentAccount.account?.id { return true }
    return false
  }

  @ViewBuilder
  private var trailingSwipeActions: some View {"""
content = content.replace("  @ViewBuilder\n  private var trailingSwipeActions: some View {", prop)

with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowSwipeView.swift", "w") as f:
    f.write(content)


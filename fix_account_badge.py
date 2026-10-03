import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowHeaderView.swift", "r") as f:
    content = f.read()

target = """  private var accountBadgeView: Text? {
    if (viewModel.status.reblogAsAsStatus ?? viewModel.status).account.bot {
      return Text(Image(systemName: "poweroutlet.type.b.fill")) + Text(" ")
    } else if (viewModel.status.reblogAsAsStatus ?? viewModel.status).account.locked {
      return Text(Image(systemName: "lock.fill")) + Text(" ")
    }
    return nil
  }"""

replacement = """  private var accountBadgeView: Text? {
    let statusToUse = viewModel.status.reblogAsAsStatus ?? viewModel.status
    let isBot = statusToUse.account.bot
    let isLocked = statusToUse.account.locked
    
    if isBot {
      return Text(Image(systemName: "poweroutlet.type.b.fill")) + Text(" ")
    } else if isLocked {
      return Text(Image(systemName: "lock.fill")) + Text(" ")
    }
    return nil
  }"""

if target in content:
    content = content.replace(target, replacement)
    print("Fixed accountBadgeView")
    with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowHeaderView.swift", "w") as f:
        f.write(content)


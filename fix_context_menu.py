import re
with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift", "r") as f:
    content = f.read()

target = """      if let server = url.host() {
        if server != viewModel.client.server {
          if !isCurrentRemoteLocal(server: server) {
            Button {
              viewModel.routerPath.navigate(to: .remoteLocalTimeline(server: server))
            } label: {
              Label("View Local Timeline", systemImage: "globe")
            }
          }
        }
      }"""

replacement = """      if let server = url.host() {
        if shouldShowRemoteLocalButton(server: server) {
          Button {
            viewModel.routerPath.navigate(to: .remoteLocalTimeline(server: server))
          } label: {
            Label("View Local Timeline", systemImage: "globe")
          }
        }
      }"""

prop = """  private func isCurrentRemoteLocal(server: String) -> Bool {
    if let last = viewModel.routerPath.path.last,
       case let .remoteLocalTimeline(remoteServer) = last,
       remoteServer == server {
      return true
    }
    return false
  }

  private func shouldShowRemoteLocalButton(server: String) -> Bool {
    if server == viewModel.client.server { return false }
    if isCurrentRemoteLocal(server: server) { return false }
    return true
  }"""

if target in content:
    content = content.replace(target, replacement)
    content = content.replace("""  private func isCurrentRemoteLocal(server: String) -> Bool {
    if let last = viewModel.routerPath.path.last,
       case let .remoteLocalTimeline(remoteServer) = last,
       remoteServer == server {
      return true
    }
    return false
  }""", prop)
    print("Fixed StatusRowContextMenu nesting")
    with open("Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift", "w") as f:
        f.write(content)


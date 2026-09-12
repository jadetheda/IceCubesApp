with open("Packages/Env/Sources/Env/Router.swift", "r") as f:
    code = f.read()

target = """    } else if (url.lastPathComponent.first == "@" || (url.pathComponents.count >= 2 && url.pathComponents[url.pathComponents.count - 2] == "users")),
      let host = url.host,
      !host.hasPrefix("www")
    {
      let acct = "\\(url.lastPathComponent)@\\(host)"
      Task {
        await navigateToAccountFrom(acct: acct, url: url)
      }
      return .handled
    }"""

replacement = """    } else if url.pathComponents.count >= 2 && url.pathComponents[url.pathComponents.count - 2] == "users" {
      Task {
        await navigateToAccountFrom(url: url)
      }
      return .handled
    } else if url.lastPathComponent.first == "@",
      let host = url.host,
      !host.hasPrefix("www")
    {
      let acct = "\\(url.lastPathComponent)@\\(host)"
      Task {
        await navigateToAccountFrom(acct: acct, url: url)
      }
      return .handled
    }"""

if target in code:
    with open("Packages/Env/Sources/Env/Router.swift", "w") as f:
        f.write(code.replace(target, replacement))
    print("Success")
else:
    print("Failed to find target block")

import re
with open("Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift", "r") as f:
    content = f.read()

target = """        if status.reblog?.mediaAttachments.isEmpty == false {
          return false
        }"""

replacement = """        let reblogEmpty = status.reblog?.mediaAttachments.isEmpty ?? true
        if !reblogEmpty {
          return false
        }"""

if target in content:
    content = content.replace(target, replacement)
    print("Fixed Optional<Bool> == Bool")
    with open("Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift", "w") as f:
        f.write(content)


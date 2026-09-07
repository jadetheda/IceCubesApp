import re

def update_file(path):
    with open(path, "r") as f:
        content = f.read()
    
    old_block = """          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Some posts are hidden by your active Content Filter")"""
          
    new_block = """          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Some posts are hidden by your active \\(String(localized: \\"timeline.content-filter.title\\"))")"""
          
    if old_block in content:
        content = content.replace(old_block, new_block)
        with open(path, "w") as f:
            f.write(content)
        print(f"Updated {path}")
    else:
        print(f"Could not find block in {path}")

update_file("Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift")
update_file("Packages/Account/Sources/Account/Detail/Tabs/StatusesTab.swift")

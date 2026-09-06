import re

def update_file(path):
    with open(path, "r") as f:
        content = f.read()
    
    old_block = """          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Some posts are hidden by your active timeline filters")
            Spacer()
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .listRowBackground(theme.primaryBackgroundColor)"""
          
    new_block = """          HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Content Filter")
            Spacer()
            Button("Change") {
              routerPath.presentedSheet = .timelineContentFilter
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowSeparator(.hidden)"""
          
    if old_block in content:
        content = content.replace(old_block, new_block)
        with open(path, "w") as f:
            f.write(content)
        print(f"Updated {path}")
    else:
        print(f"Could not find block in {path}")

update_file("Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift")
update_file("Packages/Account/Sources/Account/Detail/Tabs/StatusesTab.swift")

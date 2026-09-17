import re

# Update NavigationTab.swift
with open('IceCubesApp/App/Tabs/NavigationTab.swift', 'r') as f:
    nav_content = f.read()

# Add isListsTab parameter
nav_content = nav_content.replace(
    'var content: () -> Content',
    'var content: () -> Content\n  var isListsTab: Bool = false'
)
nav_content = nav_content.replace(
    'init(@ViewBuilder content: @escaping () -> Content) {',
    'init(isListsTab: Bool = false, @ViewBuilder content: @escaping () -> Content) {\n    self.isListsTab = isListsTab'
)
nav_content = nav_content.replace(
    'ToolbarTab(routerPath: $routerPath)',
    'ToolbarTab(routerPath: $routerPath, isListsTab: isListsTab)'
)

with open('IceCubesApp/App/Tabs/NavigationTab.swift', 'w') as f:
    f.write(nav_content)

# Update ToolbarTab.swift
with open('IceCubesApp/App/Tabs/ToolbarTab.swift', 'r') as f:
    toolbar_content = f.read()

toolbar_content = toolbar_content.replace(
    '@Binding var routerPath: RouterPath',
    '@Binding var routerPath: RouterPath\n  var isListsTab: Bool = false'
)

# Replace the statusEditorToolbarItem with conditional
conditional_toolbar = """
      if isListsTab {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            routerPath.presentedSheet = .listCreate
          } label: {
            Image(systemName: "plus")
              .accessibilityLabel("Add List")
          }
          .tint(.label)
        }
      } else {
        statusEditorToolbarItem(
          routerPath: routerPath,
          visibility: userPreferences.postVisibility)
      }
"""

toolbar_content = toolbar_content.replace(
    """      statusEditorToolbarItem(
        routerPath: routerPath,
        visibility: userPreferences.postVisibility)""",
    conditional_toolbar.strip('\n')
)

with open('IceCubesApp/App/Tabs/ToolbarTab.swift', 'w') as f:
    f.write(toolbar_content)

# Update Tabs.swift
with open('IceCubesApp/App/Tabs/Tabs.swift', 'r') as f:
    tabs_content = f.read()

tabs_content = tabs_content.replace(
    """    case .lists:
      NavigationTab {
        ListsListView()
      }""",
    """    case .lists:
      NavigationTab(isListsTab: true) {
        ListsListView()
      }"""
)

with open('IceCubesApp/App/Tabs/Tabs.swift', 'w') as f:
    f.write(tabs_content)


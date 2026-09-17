import re

with open('memory.md', 'r') as f:
    content = f.read()

new_log = """
- **2026-09-16 (UTC)**
  - **Bug Fix**: Fixed a Misskey search bug where queries that didn't exactly match a username returned a fake "Error 2" user.
  - **Context**: `MisskeyBackend` was capturing API exceptions for `/users/show` and immediately returning a hardcoded `Account(id: "error2")` instead of gracefully falling through to `/users/search`.
  - **Resolution**: Removed the fakeAccount injections in the `catch` blocks so that Misskey can properly fallback to generalized search queries.
  - **Feature**: Replaced the "New Post" button on the Lists tab with an "Add List" button.
  - **Context**: The `ToolbarTab` was globally injecting `statusEditorToolbarItem` on all `NavigationTab` instances.
  - **Resolution**: Added `isListsTab` boolean to `NavigationTab` and `ToolbarTab`. Conditionalized the trailing navigation bar item to spawn `routerPath.presentedSheet = .listCreate` when `isListsTab` is true.
"""

if "## 🪵 Activity Log" in content:
    content += new_log
else:
    print("Could not find Activity Log section")

with open('memory.md', 'w') as f:
    f.write(content)

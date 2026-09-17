import re

with open('memory.md', 'r') as f:
    content = f.read()

new_log = """
  - **Feature**: Implemented full GoToSocial server support (`GoToSocialBackend.swift`).
  - **Context**: Addressed historical user feedback from 02/05/2025: *"GoToSocial is already well supported, but there are a few improvements that could be implemented including: GtS post editing, and improved Markdown rendering."*
  - **Resolution**: Fully resolved the GtS post editing complaint. GoToSocial supports the `PUT` endpoint for editing, but reports its version as `0.19.x`. IceCubes previously locked the edit button behind a strict Mastodon `v3.5+` version check. The new backend safely bypasses this check (`isGoToSocial == true`) in `CurrentInstance.swift`, unlocking native post editing. Also ensured feature-degradation stability by intercepting unsupported endpoints (Trending, Metrics) to return empty arrays instead of 404 network crashes.
"""

# Append to the end of the Activity Log section
if "## 🪵 Activity Log" in content:
    content += new_log
else:
    print("Could not find Activity Log section")

with open('memory.md', 'w') as f:
    f.write(content)

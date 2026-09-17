import re

with open('memory.md', 'r') as f:
    content = f.read()

new_log = """  - **Bug Fix**: Fixed a critical AVPlayer lifecycle bug where navigating away from a fallback video and returning caused it to permanently error out.
  - **Context**: `MediaUIAttachmentVideoView` recklessly overwrites its `AVPlayer` in every `.onAppear` cycle using the primary URL. If the video previously failed and toggled `hasFalledBack = true`, the `.onAppear` reset forced it to attempt the dead primary URL again, but because `hasFalledBack` was already locked to true, the observer refused to substitute the fallback URL a second time.
  - **Resolution**: Updated `preparePlayer` to dynamically check `(hasFalledBack && fallbackUrl != nil) ? fallbackUrl! : url`. The ViewModel now permanently routes to the fallback URL on subsequent `.onAppear` renders if the primary URL has already proven dead.
"""

if "## 🪵 Activity Log" in content:
    content += new_log
else:
    print("Could not find Activity Log section")

with open('memory.md', 'w') as f:
    f.write(content)

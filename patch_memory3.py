import re

with open('memory.md', 'r') as f:
    content = f.read()

new_log = """  - **Feature**: Added a "Loop videos" preference toggle to `ContentSettingsView`.
  - **Context**: The user wanted a dedicated toggle to control video and animation looping, which was previously hardcoded to piggyback off the `autoPlayVideo` setting.
  - **Resolution**: Decoupled the `AVPlayerItemDidPlayToEndTime` looping logic in `MediaUIAttachmentVideoView` from `autoPlayVideo`. Injected a new `@AppStorage("loop_video")` boolean into `UserPreferences`. Set it to actively override looping everywhere across the app (timeline and fullscreen) when disabled, while letting GIFs implicitly loop as expected.
"""

if "## 🪵 Activity Log" in content:
    content += new_log
else:
    print("Could not find Activity Log section")

with open('memory.md', 'w') as f:
    f.write(content)

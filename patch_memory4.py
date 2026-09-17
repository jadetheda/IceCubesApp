import re

with open('memory.md', 'r') as f:
    content = f.read()

new_log = """  - **Bug Fix**: Fixed a critical upstream AVPlayer bug where remote videos (especially in search or fullscreen) would refuse to loop.
  - **Context**: The `AVPlayerItemDidPlayToEndTime` observer was rigidly bound to `player.currentItem`. When Misskey/Pixelfed remote videos failed to load natively and `hasFalledBack` swapped in the `fallbackUrl` via `replaceCurrentItem`, the loop observer was permanently orphaned on the dead item.
  - **Resolution**: Refactored the observer to listen globally (`object: nil`) and dynamically evaluate `item == self.player?.currentItem` inside the closure. Saved the `loopVideo` preference to the ViewModel so it flawlessly survives media swap-outs and lifecycle refreshes.
"""

if "## 🪵 Activity Log" in content:
    content += new_log
else:
    print("Could not find Activity Log section")

with open('memory.md', 'w') as f:
    f.write(content)

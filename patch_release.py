import re

with open('release_summary.md', 'r') as f:
    content = f.read()

# We will just rewrite the Bugs section entirely to be perfectly accurate.
bugs_section = """## 🐛 Pre-existing Legacy Bugs Fixed (Existed Prior to `v2.1.4.8`)

These are legacy bugs that plagued the core application prior to this update cycle, which have now been completely eradicated:

### Media & Playback Bugs
- **The "Orphaned AVPlayer Observer" (Fallback videos refusing to loop):** Fixed a deeply rooted iOS view lifecycle bug. When a remote media URL failed and triggered the `fallbackUrl`, the video engine permanently abandoned its loop-listener on the dead URL. The listener is now forcefully detached and reattached dynamically whenever a fallback swap occurs.
- **The "Fallback Memory Leak" (Navigating away permanently breaks media):** Fixed a massive lifecycle bug where if a video successfully fell back to a secondary URL, navigating away (pausing the view) and returning would force the engine to blindly reinitialize using the dead primary URL again. It now natively remembers if a URL is dead and bypasses it on refresh.
- **Fullscreen Viewer State Loss:** Fixed a state-restoration bug where tapping a successfully fallback-loaded image in the timeline would inexplicably reset it to a broken state in the fullscreen viewer (`MediaUIView`). The `effectiveUseRemoteMedia` state is now correctly propagated through the `WindowDestinationMedia` payload.

### Network & Caching Bugs
- **HTTP 500 Silent Cache Poisoning:** Fixed a severe flaw where federated instances throwing HTTP 500 errors returned empty payloads that IceCubes blindly cached in memory. This poisoned the local database and caused the app to lock up on boot. Caching is now fully defensive against network failures.
- **Cloudflare 403 / 503 WebSocket Drops:** Fixed aggressive Cloudflare connection drops that were breaking live-streaming on Aethy and Sharkey servers.
- **Aethy.com Validation Crash:** Patched the core `Instance` model decoder to tolerate empty URL strings and missing fields, fixing a hard crash when attempting to connect to Aethy.com.

### UI & Core Logic Bugs
- **App Launch Fatal Crash:** Fixed a fatal crash on boot caused by `StatusRowView` illegally trying to read a `@Environment` `StatusDataController` property that wasn't provided by its parent, completely bricking the app on startup.
- **Hide Seen Posts Visual Refresh:** Fixed a bug where pulling to refresh didn't actually visually clear read posts from the timeline because the state layout wasn't properly invalidated.
- **IceShrimp Trailing Hashtags (Inline Rendering):** IceShrimp formats hashtags as trailing anchor links without standard Mastodon CSS classes. The `HTMLString.swift` heuristic was completely rewritten using `SwiftSoup` to safely detect and parse these tags natively, without accidentally triggering false positives on standard GitHub URLs.
- **Share Sheet Compilation Crash:** Fixed the "Share as Image" context menu generation logic crashing due to missing sheet modifiers and environment variables.
- **IceShrimp Trending Fallback:** Fixed the IceShrimp trending algorithm fallback to use the v1 API instead of v2, ensuring remote instance validation works properly.
- **Boosts Tab Pagination Loop:** Fixed an infinite empty loading loop in the Boosts tab caused by missing pagination updates.
"""

new_content = re.sub(r'## 🐛 Pre-existing Legacy Bugs Fixed.*', bugs_section, content, flags=re.DOTALL)

with open('release_summary.md', 'w') as f:
    f.write(new_content)

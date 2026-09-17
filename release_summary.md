# Release v2.1.5
Hiii everyone! In the last release, I promised that the `multi-spec-support` branch was about to take over and bring Misskey and other fediverse platforms to the app. Well... it finally happened! 

This was a massive rewrite to completely rip out the hardcoded Mastodon API stuff, but we've now built an engine that hot-swaps backends on the fly,

## New to this release
- **Full Misskey & Sharkey Integration**: You can finally log in using Misskey's custom `MiAuth`! We mapped all their weird endpoints to our UI, meaning you get native support for timelines, search, profiles, bookmarks, and even Misskey's "Delete & Redraft"! 
- **Real-time WebSockets for Misskey**: Live streaming and notifications now work flawlessly for Misskey/Sharkey servers using their custom WebSocket channels.
- **Custom Misskey Reactions**: The native Like button now intelligently sends either a ❤️ or ⭐ reaction to Misskey based on your settings, and we parse inbound custom emoji reactions.
- **Native Pixelfed Support**: We built a dedicated Pixelfed backend that handles their weird API quirks. *We also unlocked native post editing for Pixelfed servers!*
- **Native GoToSocial Support**: GoToSocial is fully supported now! The app will gracefully hide features they don't support (like Trending Links) instead of crashing.
- **Dedicated "Loop Videos" Setting**: I decoupled video looping from the "Autoplay" setting! You can now toggle "Loop Videos" independently in Content Settings.
- **Double-Tap Quick Account Switch**: Double-tapping your profile icon in the top left now instantly switches you to your last-used profile. *Super handy!*
- **Settings Overhaul**: The `ContentSettingsView` and `DisplaySettingsView` were getting ridiculously bloated. We extracted the IceShrimp workarounds into `ExploreAlgorithmSettingsView` and layout settings into `GallerySettingsView` to clean things up.
- **App Settings Backup Restored***: The "Backup App Settings" and "Restore" features are fully functional again, and they now correctly save all of our new custom preferences.
- **Gallery Mode is Default**: I went ahead and enabled the Gallery Mode toggle by default in the Timeline menu.
- **Contextual Lists FAB**: The big "New Post" button now dynamically transforms into an "Add List" button when you're looking at the Lists tab.
- **Cross-Instance Misskey Routing**: We added native interceptors so those legacy `/users/UUID` URLs and cross-instance Misskey profiles open beautifully in the app instead of kicking you out to Safari.

*You might need to re-export your settings if you did it on the older version.

### so many bug fixes...
so many.  but, my favorite is:
- **Remote Media Fallbacks are finally fixed!** *I promised this in the last release! If a remote video fails to load (like on IceShrimp), the app used to permanently abandon its loop-listener. We re-engineered the AVPlayer lifecycle so fallback videos will always loop flawlessly.*
- Fixed a massive bug where navigating away from a successfully fallback-loaded video and returning would force the engine to blindly reinitialize using the dead primary URL again. It now remembers if a URL is dead!
- Fixed a severe flaw where instances throwing HTTP 500 errors returned empty payloads that the app blindly cached, which would poison the database and lock up the app on boot.
- Fixed aggressive Cloudflare connection drops that were breaking live-streaming on Aethy and Sharkey servers.
- Patched the core decoder to tolerate empty URL strings, fixing a hard crash when connecting to Aethy.com.
- Fixed the issue where pulling to refresh didn't actually visually clear your read posts from the timeline. 
- Rewrote the HTML heuristic to safely detect and parse IceShrimp tags natively without triggering false positives on standard GitHub URLs.
- Fixed a legacy UI bug where the "Share as Image" context menu action was completely broken because the sheet modifiers were missing from the view hierarchy.
- Fixed the algorithm fallback to use the v1 API instead of v2, ensuring remote instance validation works properly.
- Fixed an infinite empty loading loop in the Boosts tab caused by missing pagination updates.
- probably more, ive been kinda hyper-focusing...

## Known bugs
- With the massive multi-spec rewrite, there are bound to be some undiscovered edge cases when interacting with heavily modified fediverse forks. Let me know what you find!

Hope u enjoy! <3

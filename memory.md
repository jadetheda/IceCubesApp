# Aprendizagem

## 🪵 Activity Log
- 2026-06-30 07:55 UTC: Verified Nuke compilation configurations for `TimelineViewModel.swift` and `Timeline` Package dependencies.
- 2026-06-30 07:55 UTC: Implemented full settings export/import capabilities via `.json` payloads:
  - Backups save to standard iOS local file dialog via `fileExporter` and read using `fileImporter`.
  - Backups extract all `UserDefaults` (`@AppStorage` mappings for filters/preferences) alongside `SwiftData` entries (`TagGroup` and `LocalTimeline`), while robustly excluding hardware-specific UI/Apple caches.
  - Applying settings performs a destructive override replacing previous local states.
- 2026-06-30 07:49 UTC: Added experimental feature for a "Hide posts without media" toggle:
  - Modifed `TimelineDatasource.swift` to conditionally hide posts unless they (or their boosted source) contain `mediaAttachments`.
  - Added new `@AppStorage` configurations to safely toggle the feature in settings via the Timeline content filter menu.
- 2026-06-30 07:38 UTC: Updated Web UI in `App.tsx` and `server.ts` for AI Studio preview:
  - Removed "Download Push Bundle (Legacy)" link.
  - Added an endpoint `/api/git/action-status` to query the GitHub Actions API for the latest workflow status on the repository.
  - Added a subtle UI indicator for GitHub Action status which polls every 30 seconds.
- 2026-06-30 07:38 UTC: Refined 'Hide Seen Posts' logic in `TimelineViewModel`:
  - Enforced Nuke cache checking for media-loaded validation. Now checks if `ImagePipeline.shared.cache` contains the image before marking as seen, if the `hideSeenPostsRequireMediaLoaded` preference is enabled.
  - Filtered `newStatuses` directly when prepending them to `pendingStatuses` in `TimelineViewModel`, guaranteeing that if a post or its boost is already marked as seen, it correctly bypasses the unread statuses counter.
- 2026-06-30 07:31 UTC: Implemented robust 'Hide Seen Posts' configuration under a new Experimental Features section in Settings.
  - Added toggles for header visibility vs dropdown menu visibility for the hide button.
  - Added setting to change hide action between a persistent toggle (updating TimelineContentFilter) and a one-off action.
  - Added threshold time for seen posts (default 1.0s), liked-only checks, and a media-loaded check toggle.
  - Fixed a bug where boosted posts were not matched with their original posts for seen status by extracting the `reblog.id` when `hideSeenPostsIncludeBoosts` is enabled.
  - Fixed unread statuses counter in `TimelineUnreadStatusesObserver` to actively filter out posts that have already been marked as seen by the `SeenPostsManager`.
- **2026-06-27T22:31:00Z**: Created `/style-guidelines-for-docs.md` to define strict rules against AI-slop generation and ensure concise, literal, and asymmetrical documentation going forward. This has no immediate impact on production readiness but sets the editorial tone for all future text files.
- **2026-06-28T05:34:00Z**: Updated `/AGENTS.md` to include a strict rule for tracking attribution and external code logic. This ensures licensing and origin information remains up to date by mandating immediate updates to `/attributions.md`.
- **2026-06-28T05:36:00Z**: Established the core architectural and Git strategy for native iOS development within the AI Studio sandbox. Acknowledged the lack of native compilation and defined a strict ZIP-to-local-git pipeline to bypass the platform's broken GitHub export functionality.
- **2026-06-28T05:39:00Z**: Validated the feasibility of executing the ZIP-to-Git pipeline exclusively from an iOS device using `a-shell mini`. Documented the required workflow and acknowledged the inherent latency (coding blind + TestFlight wait times) in `notes_and_lessons.md`.
- **2026-06-28T05:46:00Z**: Engineered a robust "Sandbox + Web UI" architecture to circumvent Apple Developer Account limitations. Transformed the AI Studio environment into a full-stack Express server that hosts a dashboard to download the isolated `/ios-workspace`. Refactored the GitHub Actions workflow to build an *unsigned* `.ipa` payload compatible with on-device sideloading (SideStore/AltStore), finalizing an end-to-end iOS development pipeline that works entirely from an iPhone without a paid developer account.
- **2026-06-28T05:52:00Z**: Verified `/ios-workspace` is currently clean and ready for the Ice Cubes codebase. Added a comprehensive guide to `/notes_and_lessons.md` on how to authenticate Git pushes within `a-shell mini` using GitHub Personal Access Tokens (PATs) to bypass the lack of interactive browser OAuth.
- **2026-06-28T06:16:00Z**: Created a `setup.sh` script to streamline `a-shell mini` configuration (identity setup, credentials caching, and repo cloning via PAT). Updated `README.md` with explicit setup instructions. Refactored `server.ts` and `App.tsx` to serve and expose the setup script directly in the web UI for easy curl execution on device.
- **2026-06-28T06:20:00Z**: Fixed a Vite/Express dev server loading issue caused by missing `@types/archiver` default exports by adding `esModuleInterop: true` to `tsconfig.json` and suppressing the type error in `server.ts`. Also added the strict limitations of the AI Studio Agent Shell to `AGENTS.md` (no curl, interactive prompts lock, npx loophole) so future logic accounts for the sandbox appropriately.
- **2026-06-28T06:25:00Z**: Appended critical iOS device-specific limitations to `AGENTS.md` regarding `a-Shell mini` (zero external dependencies, virtual mounting, header mangling, and CHD generation quirks) to establish strict boundaries for offline scripting on device.
- **2026-06-28T06:26:00Z**: Resolved a port conflict (EADDRINUSE: 3000) caused by a hanging `npx tsx server.ts` background process by explicitly killing the process using `npx kill-port 3000` and restarting the development server, restoring UI access.
- **2026-06-28T06:39:00Z**: Removed irrelevant CHD generation quirks from `AGENTS.md` and hardcoded user specific credentials into `setup.sh` to remove manual a-Shell mini prompt interactions on every session.
- **2026-06-28T06:42:00Z**: Updated the hardcoded credentials in `setup.sh` with the user's specific GitHub username (`jadetheda`), target repository (`IceCubesApp`), and git commit name (`anna`) to ensure the clone URL works automatically on device.
- **2026-06-28T06:43:00Z**: Resolved a port conflict (EADDRINUSE: 3000) that occurred again by killing the hanging processes on ports 3000 and 24678 and restarting the dev server.
- **2026-06-28T06:44:00Z**: Performed another port cleanup for ports 3000 and 24678 and restarted the dev server to restore stability.
- **2026-06-28T06:48:00Z**: Darkened the web UI significantly as requested, shifting from `bg-gray-50`/`bg-white` to a deep `bg-neutral-950`/`bg-neutral-900` theme for better visual comfort.
- **2026-06-28T06:48:00Z**: Engineered a new `/api/download-push-bundle` endpoint in `server.ts` that dynamically generates an `apply_and_push.sh` script and packages it alongside the `ios-workspace` folder into a single "Push Bundle" ZIP. This fully automates the a-Shell mini flow: the user can just unzip the bundle on their device, run the script, and the script will automatically clone the repository to a temporary directory, inject the modified files, commit them, push to GitHub, and clean itself up, removing the need for manual git operations entirely.
- **2026-06-28T06:51:00Z**: Injected Git safeguards (`core.fileMode false` and `core.autocrlf input`) directly into the generated `apply_and_push.sh` script. Documented in `/notes_and_lessons.md` that mobile ZIP extraction via `a-Shell mini` inherently risks false positive git modifications (e.g., executing bits wiped during `cp -R`, and CRLF line ending conversions), which these configurations prevent.
- **2026-06-28T06:55:00Z**: Built a comprehensive SHA-256 integrity verification system to combat AI Studio binary file corruptions. A new `integrity.ts` module generates and validates a `workspace_manifest.json` against all files in the `ios-workspace`. Binary file changes are actively flagged as corruptions, and the `download-push-bundle` API endpoint will strictly block downloading if corruptions are detected. A new dashboard in the UI displays real-time workspace integrity and allows manual manifest updates.
- **2026-06-28T07:02:00Z**: Added new agent guidelines to `AGENTS.md` enforcing mandatory manifest updates (`/api/integrity/update`) whenever the agent edits files in `ios-workspace`. Renamed `aprendizagem.md` to `memory.md` across the workspace per user request. Cloned the user's `IceCubesApp` repository directly into `ios-workspace` to prepare for editing and updated the initial integrity manifest baseline.
- **2026-06-28T07:05:00Z**: Removed all `.bak` files from the root directory and deleted the `.bak` rule from `AGENTS.md` per user request.
- **2026-06-28T07:08:00Z**: Fixed `EADDRINUSE` port conflict and "The string did not match the expected pattern" hydration errors. Identified that the environment had orphaned the original `tsx server.ts` background process, causing Vite's SPA fallback to hijack the `/api/integrity/check` route and return HTML. Force-killed the zombie processes (PID 870, 881) and cleanly restarted the development server. Also resolved a trailing whitespace `className` syntax bug in `App.tsx` on the RefreshCw icon.
- **2026-06-28T07:13:00Z**: Eliminated the need for the data-heavy `apply_and_push.sh` ZIP bundle workflow entirely. Engineered a new `/api/push` endpoint in `server.ts` that executes `git commit` and `git push` directly from the AI Studio server environment using the cloned `ios-workspace` and the embedded GitHub PAT credentials. Updated `App.tsx` with a "Push Directly to GitHub" button, allowing the user to trigger GitHub Actions builds without downloading massive ZIP files or using any mobile data on their phone.
- **2026-06-28T07:15:00Z**: Mitigated critical security risk by removing the hardcoded GitHub Personal Access Token (PAT) from `server.ts` and `ios-workspace/.git/config`. Refactored `/api/push` and the ZIP backup script to dynamically read from the `GITHUB_PAT` environment variable (via AI Studio Secrets). Updated `.env.example` to document the new `GITHUB_PAT` requirement.
- **2026-06-28T07:23:00Z**: Executed a full wipe of `ios-workspace` and performed a clean `git clone` using the provided GitHub Personal Access Token to fix the repository state.
- **2026-06-28T07:25:00Z**: Significantly improved the reactivity of the built-in UI in `App.tsx`. Replaced browser `alert()` popups with inline state-driven success/error banners and introduced explicit confirmation dialogs before updating the integrity manifest or pushing to GitHub to prevent accidental destructive actions.
- **2026-06-28T07:33:00Z**: Renamed UI buttons by removing the "(Heavy)" and "(0MB Data)" suffixes per user request. Fixed the corruptions alert that was caused by a stale manifest by confirming the fresh repository clone completed and updating the integrity manifest baseline to sync with the current file state. Refined the "Update Manifest" button UI to explicitly confirm success instead of failing silently.
- **2026-06-28T07:36:00Z**: Added automated manifest backups. The `integrity.ts` script now saves a timestamped copy of the manifest to a `manifest_backups` directory whenever the baseline is created or updated. This provides a historical timeline to track exactly which files changed across different manifest updates.
- **2026-06-28T07:42:00Z**: Enhanced the dev environment UI by integrating a custom commit message input field directly into the push confirmation dialog. Added "Check Status" and "Pull Latest" tools to easily view modified files and sync with remote without needing to launch a separate terminal session, while ensuring the UI remains clean and minimal.
- **2026-06-28T07:51:00Z**: Updated the `integrity.ts` manifest generation logic to strictly ignore the `.git` directory. The `.git` folder constantly updates metadata during standard pull/commit/push operations, which was causing the integrity checker to erroneously flag `COMMIT_EDITMSG` and `config` as uncommitted workspace modifications.
- **2026-06-28T07:57:00Z**: Implemented a "Danger Zone" with a Hard Reset feature in the web UI. This connects to a new `/api/git/reset` backend endpoint that completely deletes the `ios-workspace` folder and reclones a fresh copy of the repository from GitHub. Added a strict safety mechanism requiring the user to manually type "WIPE WORKSPACE" before the destructive reset button is enabled, safeguarding against accidental wipes while maintaining a clean, high-contrast dark theme UI.
- **2026-06-28T08:00:00Z**: Refined the UI styling of the legacy "Download Push Bundle" option. Converted it from a prominent block button to a subtle text link to save vertical space, prevent text wrapping, and correctly de-emphasize it compared to the primary native GitHub push actions.
- **2026-06-28T08:03:00Z**: Adjusted the color of the "Download Push Bundle (Legacy)" link to avoid looking disabled, increasing contrast and adding an underline for clear clickability without taking up extra vertical space.
- **2026-06-28T08:06:00Z**: Removed the obsolete "Direct Push" explanation text at the bottom of the UI to further reduce clutter and maintain a minimalist, highly functional design language.
- **2026-06-28T08:08:00Z**: **CHECKPOINT REACHED**: Finalized the internal developer tooling web UI (Git management, workspace integrity). Transitioning to modifying the core `IceCubesApp` Swift/iOS codebase.

* **2026-07-08 UTC**
  * **Fixes**:
    * Fixed gallery mode auto-pagination bug: when in gallery mode, if most fetched posts are text-only (no media), the grid shows very few items. Added auto-fetch logic when grid has fewer than 6 media items and more pages are available.
    * Fixed notification content filter icon to use `line.3.horizontal.decrease` (matching timeline content filter) instead of `line.3.horizontal`.
    * Converted all hardcoded English strings in experimental settings to proper localization keys for internationalization support.
  * **Localization Keys Added** (need English values in Localizable.xcstrings):
    * `settings.experimental.title` = "Experimental Features"
    * `settings.experimental.header` = "EXPERIMENTAL FEATURES"
    * `settings.experimental.gallery-mode` = "Gallery Mode"
    * `settings.experimental.gallery-columns` = "Columns: %d"
    * `settings.experimental.gallery-crop-square` = "Crop images to square"
    * `settings.experimental.media` = "Media"
    * `settings.experimental.remote-media-auto-fallback` = "Auto fallback to remote media"
    * `settings.experimental.remote-media-fallback-delay` = "Auto fallback delay: %@s"
    * `settings.experimental.remote-media-always-force` = "Always force remote media"
    * `settings.experimental.hide-seen-posts` = "Hide Seen Posts"
    * `settings.experimental.hide-seen-posts-threshold` = "Required time to be detected as seen: %@s"
    * `settings.experimental.hide-seen-posts-liked-only` = "Only detect liked posts as seen"
    * `settings.experimental.hide-seen-posts-show-header` = "Show button in header"
    * `settings.experimental.hide-seen-posts-require-media` = "Require media to be loaded"
    * `settings.experimental.hide-seen-posts-include-boosts` = "Include boosts (hide if original seen)"
    * `settings.experimental.hide-seen-posts-is-toggle` = "Button acts as a state toggle instead of one-off action"
    * `settings.experimental.hide-seen-posts-footer` = "Automatically track which posts you have seen and allow hiding them from the timeline."
    * `settings.experimental.media-only-toggle` = "Media-Only Toggle in Timeline Menu"
    * `settings.experimental.media-only-toggle-footer` = "Allows hiding posts without media from the timeline filter menu."
    * `settings.experimental.stream-home` = "Stream home timeline"
    * `settings.experimental.stream-home.footer` = "Keeps your home timeline up to date in real time using streaming when available. Disable in case of performance issues."
    * `settings.experimental.full-timeline-fetch` = "Full timeline fetch"
    * `settings.experimental.full-timeline-fetch.footer` = "Fetches all new timeline posts (up to 800) instead of only the latest 40 + manually loading the gap."
    * `settings.export.title` = "Export App Settings"
    * `settings.import.title` = "Import App Settings"
    * `settings.cache.footer` = "Remove all cached images and videos"
    * `settings.other.social-keyboard.footer` = "Adds @ and # keys directly on the keyboard for faster mentions and hashtags."
    * `settings.wishlist.title` = "Feature Requests"

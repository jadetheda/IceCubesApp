# Modifications Since Release v2.1.4.3

This document catalogs every file modified or added to the repository since the `v2.1.4.3` release (July 18, 2026). It outlines the exact changes made to each file.

---

## 1. Main Application Target (IceCubesApp)

### `IceCubesApp.xcodeproj/project.pbxproj`
- Integrated custom configurations for the Nuke data cache pipeline.
- Bumped application bundle version to `2.1.4.4`.

### `IceCubesApp/App/Main/AppView.swift`
- Added an `.onAppear` callback to initialize `StatusBarTapTracker.shared.setup()`. This overlay captures status bar touch events.

### `IceCubesApp/App/Main/IceCubesApp.swift`
- Imported `Nuke` and `NukeUI` modules at the entry point.

### `IceCubesApp/App/Router/AppRegistry.swift`
- Registered the new `.remoteLocalTimeline(server: String)` route destination.
- Renders a standard `TimelineView` with the timeline type set to `.remoteLocal(server: server, filter: .local)`.

### `IceCubesApp/App/Tabs/ExploreTab.swift`
- Imported `SwiftData` for local database access.
- Added `@Query(sort: \LocalTimeline.creationDate, order: .reverse) var localTimelines: [LocalTimeline]` to query user-saved local timelines.
- Added a toolbar menu button (globe/waves icon) next to the compose button that lists all saved local instances and allows adding new instances via `.addRemoteLocalTimeline`.

### `IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift`
- Added a toggle for `cacheServerEmotes` under the "Other" settings section.
- Added a "Display Mode" settings section for non-visionOS platforms:
  - Added a "Text posts" toggle (the inverse of `contentFilter.hidePostsWithoutMedia`), disabled when Gallery Mode is active.
  - Added a "Media posts" toggle (the inverse of `contentFilter.hidePostsWithMedia`).
  - Added a "Gallery mode" toggle (`contentFilter.isGalleryMode`). When enabled, it automatically forces `contentFilter.hidePostsWithMedia` to `false`.

### `IceCubesApp/App/Tabs/Settings/SettingsTab.swift`
- Added an "Undo Scroll To Top" section in the `ExperimentalSettingsView` containing:
  - Toggle for `preferences.undoScrollToTopEnabled`.
  - Stepper for `preferences.undoScrollToTopTimeout` ranging from 1 to 60 seconds.
- Removed the obsolete `preferences.hideSeenPostsRequireMediaLoaded` toggle.

### `IceCubesApp/Resources/Localization/Localizable.xcstrings`
- Updated localization string for the main menu toggle from `"Media-Only Toggle in Timeline Menu"` to `"Gallery Mode Toggle in Timeline Menu"`.

---

## 2. Shared Environment Package (`Env`)

### `Packages/Env/Sources/Env/Router.swift`
- Appended `.remoteLocalTimeline(server: String)` to the `RouterDestination` enum.

### `Packages/Env/Sources/Env/StatusBarTapTracker.swift` (New File)
- Implemented `StatusBarWindow`, a `UIWindow` subclass overlaying the system status bar. It intercepts touches within the top 50 points of the screen and posts a `.statusBarTapped` notification.
- Implemented `StatusBarTapTracker` as a MainActor-isolated singleton to instantiate the tracking window.

### `Packages/Env/Sources/Env/UserPreferences.swift`
- Added persistent AppStorage keys:
  - `cache_server_emotes` (boolean, defaults to true)
  - `undo_scroll_to_top_enabled` (boolean, defaults to true)
  - `undo_scroll_to_top_timeout` (double, defaults to 10.0 seconds)
- Bound these keys to computed properties with explicit `didSet` observers that update the underlying persistent storage dictionary.

---

## 3. Account Package (`Account`)

### `Packages/Account/Package.swift`
- Added `Timeline` as a package dependency for the `Account` library.

### `Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift`
- Imported the `Timeline` package.
- Added a "View Local Timeline" button (using globe system icon) to the user details context menu when viewing accounts from other servers (derived by comparing `account.url?.host()` with the current `client.server`).
- Added a shortcut button to launch the timeline content filter configuration sheet (`.timelineContentFilter`).

### `Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift`
- Injected `UserPreferences` into the grid environment.
- Configured media URL resolution to match `StatusRowMediaPreviewView`: uses `effectiveUseRemoteMedia` (on-demand or forced) to resolve primary and fallback URLs.
- Added `remoteMediaAutoFallback` support via an active Task on appear. If visible grid images fail to load within the configured delay, it automatically falls back to fetching remote server media.

### `Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift`
- Imported the `Timeline` package.
- Modified list row rendering: if the global timeline filter has `isGalleryMode` enabled and `useTimelineFilter` is active (the profile timeline context), it renders the `GalleryStatusesListView` instead of the default linear row views.
- Added a `filteredStatuses` helper method to apply local media filters (hiding text-only posts or media-only posts) directly inside profile feeds.

---

## 4. Models Package (`Models`)

### `Packages/Models/Sources/Models/Emoji.swift`
- Changed properties `url` and `staticUrl` from type `URL` to `String`. This prevents JSON decoding crashes when the Mastodon API returns empty strings or malformed URLs for custom emoji elements.

---

## 5. Design System Package (`DesignSystem`)

### `Packages/DesignSystem/Sources/DesignSystem/Views/EmojiText.swift`
- Updated emoji collection initializer to use `compactMap` instead of `map`. It attempts to cast string emojis to `URL(string:)` and silently drops any invalid entries instead of failing.

---

## 6. Status Kit Package (`StatusKit`)

### `Packages/StatusKit/Sources/StatusKit/Editor/Components/CustomEmojisView.swift`
- Implemented an isolated, custom `ImagePipeline` configuration. It respects the `cacheServerEmotes` user preference, completely disabling both memory and disk caching when disabled.
- Updated internal `LazyImage` loaders to instantiate URLs using `URL(string: emoji.url)` to match the new string-based Emoji schema.

### `Packages/StatusKit/Sources/StatusKit/List/GalleryGrid.swift` (New File)
- Implemented `GalleryGrid` to handle grid-based media rendering. It builds a Masonry-like layout using an array of `LazyVStack` columns. Columns are populated dynamically using index modulo division based on `UserPreferences.shared.galleryColumns`.

### `Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift`
- Refactored `GalleryMediaCell` and `GalleryAspectRatioModifier` to be `public` structs to allow usage in other modules (such as `Account`).
- Marked the body properties and initializers of these structures as `public` to satisfy protocol conformance rules in multi-package builds.

### `Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowContextMenu.swift`
- Added a "View Local Timeline" option to the context menu of status items originating from remote instances, letting users quickly jump to the remote instance's local timeline.

---

## 7. Timeline Package (`Timeline`)

### `Packages/Timeline/Sources/Timeline/View/TimelineListView.swift`
- Subscribed to `.statusBarTapped` notifications and linked them to `viewModel.handleScrollToTopTrigger(proxy:)`.
- Modified tab double-tap handler to leverage the custom undo-scroll-to-top behavior rather than jumping directly to index 0.

### `Packages/Timeline/Sources/Timeline/View/TimelineView.swift`
- Added custom top-level navigation bar menus for list-based timelines, providing options for toggling Gallery Mode and opening content filters.

### `Packages/Timeline/Sources/Timeline/View/TimelineViewModel.swift`
- Introduced `previousScrollPosition` and `undoTimer` tracking variables.
- Implemented `handleScrollToTopTrigger(proxy:)`. Tapping the status bar or the tab button first scrolls to the top and saves the original position. A subsequent tap within the timeout interval (e.g., 10 seconds) undoes the action by scrolling back down to the saved item.
- Optimized pull-to-refresh: synchronized seen-posts tracking to prevent out-of-order state application when fetching newest statuses.

---

## 8. Root-Level Configuration and Non-Code Files

### `README.md`
- Rebranded headers to Community Edition. Added Dimillian and AI contribution credits.

### `todo.md`
- Logged new visual and behavioral tasks (ellipsis menu conflicts, image cropping constraints).

### Diagnostic Logs
These logs contain runtime tracking outputs captured during the debugging process of the emoji cache, timeline rendering, and status row lifecycle:
- `datasource_log.txt`
- `listview_diff.txt`
- `row_viewmodel_log.txt`
- `timeline_log.txt`
- `viewmodel_diff.txt`

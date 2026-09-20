# Comprehensive Settings Architecture & Execution Plan

## 1. Upstream Organization Philosophy (Semantic Boundaries)
Upstream IceCubesApp maintains a strict separation of concerns between its settings views. 
- **`ContentSettingsView` (Data, Behavior, and Filtering)**: Exclusively for settings that intercept or alter **data**. If a toggle changes what is fetched from the API, what is stripped out of the datasource array, or how the app behaves logically, it belongs here.
- **`DisplaySettingsView` (Layout, Chrome, and Aesthetics)**: Exclusively for settings that alter **spatial layout, UI Chrome presence, and visual themes** without altering the underlying data.

## 2. Upstream UX Philosophy (Managing Bloat)
Upstream strictly manages UI bloat using a "Shallow View" paradigm. Core views like `ContentSettingsView` are restricted to simple 1-line toggles. **Any feature that requires complex, multi-variable configuration (e.g., Sliders + Steppers + Multiple Toggles) is immediately extracted into a dedicated `NavigationLink` sub-view**. Exception: Single-modifier sliders (like `maxReplyIndentation`) stay inline.

## 3. Upstream Label Conventions & Localization
Upstream IceCubesApp strictly adheres to the following naming conventions for settings:
1. **Sentence case**: Standard toggles use sentence case (with rare upstream Title Case exceptions for hardcoded English keys, like "Compact Layout").
2. **Positive/Negative Phrasing**: Upstream uses "Show [Item]" when additive (e.g., "Show replies"), and "Hide [Item]" when subtractive (e.g., "Hide posts from bots").
3. **Localization**: Apple's String Catalogs (`Localizable.xcstrings`) are strictly used. Any new label must be appended to the catalog.

---

## 4. Analysis & Execution Plan for Custom Features

Our custom features currently violate the conventions above. They are bloated, injected directly inline rather than in sub-views, and cause massive UX fragmentation. Below is the master plan to fix them:

### A. The "Toolbar & Filter Menu" Toggles (UI Access Options)
- **Current State**: `showHidePostsWithoutMediaToggle` (Gallery Toggle in filter menu) is wrongly placed inside `ContentSettingsView`.
- **Action Plan**: Move `showHidePostsWithoutMediaToggle` to a new `Section("Toolbar & Filter Menu")` inside `DisplaySettingsView.swift`. This perfectly mirrors the upstream `showTimelineHidePinnedToggle` pattern for timeline menu buttons.

### B. Gallery Mode (The Contextual Dependency)
- **Current State**: Bloats `DisplaySettingsView` with 5 inline layout toggles, while the master `isGalleryMode` toggle sits in `ContentSettingsView`.
- **Analysis**: We cannot move `isGalleryMode` into a subview because it controls the `.disabled()` state of the "Text posts" toggle in `ContentSettingsView`. If hidden, users won't know why "Text posts" is disabled. Furthermore, the 5 configuration toggles (columns, margins, rounding) are pure **Display/Layout** parameters.
- **Action Plan**:
  1. Leave the master `isGalleryMode` toggle inline exactly where it is in `ContentSettingsView`.
  2. Extract the 5 layout configuration toggles from `DisplaySettingsView` into a dedicated `GallerySettingsView.swift` and link it via `NavigationLink` from **`DisplaySettingsView`** (where layout settings belong).
- **Label Fixes**: 
  - "Multi-Image Grid Layout" -> **"Use grid layout for multiple images"** (Note: ensure we update the `.xcstrings` key if required, without breaking Apple localization).

### C. Text, Media, and Bot Post Filters
- **Current State**: Located under an inaccurate "Display Mode" section in `ContentSettingsView`.
- **Analysis**: These are pure content filters.
- **Action Plan**: Delete the inaccurate "Display Mode" header completely. Move "Text posts", "Media posts", AND `hidePostsFromBots` (which would otherwise be orphaned) directly into the native `timeline.content-filter.title` section.
- **Label Fixes**:
  - "Text posts" -> **"Show text posts"** (Must add translation key to `Localizable.xcstrings`)
  - "Media posts" -> **"Show media posts"** (Must add translation key to `Localizable.xcstrings`)

### D. Hide Seen Posts
- **Current State**: A massive 6-variable block injected directly into the middle of `ContentSettingsView`.
- **Analysis**: Splitting the configuration of a single custom feature across two entirely different tabs (e.g., putting its toolbar toggle in Display) is a UX nightmare. All configuration must remain co-located.
- **Action Plan**: 
  1. Restore `HideSeenPostsSettingsView.swift` and link it via `NavigationLink` from `ContentSettingsView`.
  2. Delete the massive inline block (`Lines 219-243`) in `ContentSettingsView.swift`.
  3. Ensure **all** Hide Seen Posts toggles (including `hideSeenPostsShowInHeader`) remain strictly inside `HideSeenPostsSettingsView`.

### E. IceShrimp.net Explore Algorithm
- **Current State**: A bloated inline section that secretly hijacks `Mastodon` to force `Decaying Score`.
- **Action Plan**:
  1. Extract this inline block into an `ExploreAlgorithmSettingsView.swift` linked from `ContentSettingsView`. The label will explicitly be **"IceShrimp.net explore algorithm"**.
  2. In `UserPreferences.swift`, mutate `TrendingAlgorithm.localCases` to return only `[.simpleScore, .decayingScore]` so `.mastodon` is hidden from the UI Picker.
  3. Add an `.onAppear` modifier to silently migrate users: `if userPreferences.trendingAlgorithm == .mastodon { userPreferences.trendingAlgorithm = .decayingScore }`.
- **Label Fixes**:
  - `Mastodon (Default)` -> (Hidden entirely)
  - `Simple Score` -> **"Sort by top"**
  - `Decaying Score (IceShrimp fallback)` -> **"Mastodon replica"**
  - `"Posts to Search: 40"` -> **"Posts to search: 40"**

### F. Miscellaneous Display Label Fixes
- "Hide interaction buttons on Timeline" -> **"Hide interaction buttons"** (Must add to `.xcstrings`)
- "Show 'Hide Pinned' in Timeline Menu" -> **"Show hide pinned button in filter menu"**
- "Hide Pinned Items Symbol" -> **"Hide pinned items indicator"**
- "Compact Layout" -> **"Use compact layout"** (Unless breaking upstream Title Case is impossible)
- "Boost Button Behavior" -> **"Boost button behavior"** (Unless breaking upstream Title Case is impossible)

### G. Settings Backup / Restore (The "Experimental" Leftover)
- **Current State**: In `SettingsTab.swift`, the `settingsBackupSection` (Export/Import JSON) is sitting underneath the `settings.experimental.header` ("Experimental Features") header. 
- **Action Plan**: Rename the header for `settingsBackupSection` from `"settings.experimental.header"` to `"Backup & Restore"`.

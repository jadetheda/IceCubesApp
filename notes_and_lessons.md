# Notes and Lessons

## iOS Development & Deployment Pipeline
The primary development environment for this project is highly unconventional: writing Swift/SwiftUI for an iOS app from within AI Studio, with no Mac, Xcode, or paid Apple Developer account.

**Why this is necessary:**
AI Studio's native GitHub push mechanism is destructive to complex Xcode projects. It ignores `.gitignore` rules, bloats the repo with binary files, and mangles file structures. We strictly avoid it.

**Current Workflow:**
1. **Code Generation:** Modify the Ice Cubes source code here in AI Studio inside the isolated `/ios-workspace` sandbox.
2. **Push:** The agent pushes directly via the `/api/push` endpoint on request — no user interaction with the web dashboard needed. This commits and pushes straight from the AI Studio server using a `GITHUB_PAT` stored in AI Studio Secrets (env var), with no manual git commands, PAT-typing, or on-device steps.
3. **Compilation:** Builds run on **Codemagic**, manually triggered by the user from the Codemagic UI (not on automatic push). This produces an **unsigned** `.ipa`.
4. **Distribution (No Apple Dev Account):** Download the unsigned `.ipa` artifact from Codemagic and sideload it onto your device using **LiveContainer**.

**The Reality of the Feedback Loop:**
You are essentially "coding blind." You cannot run local Xcode previews. Every UI tweak or logic change requires the agent to push from AI Studio, then the user manually starting a Codemagic build, waiting 10-15 minutes for it to compile an unsigned `.ipa`, and sideloading it via LiveContainer. It is slow, but entirely possible to build and test native iOS apps directly from an iPhone without a Mac or a paid Apple developer account.

## ⚠️ Mobile Extraction False Positives
When working with source code within AI Studio and extracting it on an iOS device (`a-Shell mini`), there is a very high likelihood of Git detecting "false positive" modifications. 

These occur because standard iOS file extraction and basic `cp` commands do not respect UNIX file system nuances the way a native macOS/Linux environment would. The two biggest offenders are:

1. **File Permissions (`chmod`)**: `a-Shell mini` is a sandboxed iOS app. When you unzip files and copy them over, executable flags (like `100755` on shell scripts or binaries) are often wiped to `100644`. Git detects this as a file modification (`old mode 100755 new mode 100644`).
2. **Line Endings (CRLF vs LF)**: Sometimes, archiving and unarchiving text files across environments accidentally normalizes or converts line endings. If LF (`\n`) is converted to CRLF (`\r\n`), Git will flag the entire file as modified.

**The Fix:** Apply protective Git configurations whenever workspace files are extracted or synced from a ZIP payload (e.g. via `wipe_and_load.mjs` / `sync_repo.sh`) to neutralize these threats before committing:
- `git config core.fileMode false` (Forces Git to ignore executable bit changes).
- `git config core.autocrlf input` (Normalizes line endings on commit).

## AI Studio Workspace Replacement Strategy
- **File Deletion Limit / Cost**: Deleting many individual files using standard token-heavy edits or shell loops can be very inefficient in AI Studio.
- **Solution (`replace_workspace.sh`)**: When completely replacing a codebase from a new ZIP (like from a direct GitHub URL or provided user link), always use an automated script (like `replace_workspace.sh`).
  - This script downloads the ZIP via `npx` (to bypass missing `curl`/`wget`).
  - It wipes the workspace using `find` (preserving crucial `.git`, `.env`, and `ios-workspace` folders).
  - It extracts the clean structure over the old one.
  - This avoids tedious manual file-by-file wiping.

## Background Task & Browser Automation Tracking
- **The Issue**: Long-running background tasks (like Playwright browser automation scripts or file scrapers, e.g., `dl4.cjs`) were executed without being properly tracked in `memory.md`.
- **The Lesson**: EVERY background task, especially those involving external navigation or headless browsers, MUST be documented in `memory.md` immediately upon execution, including the purpose of the task and its expected outcome. If it fails or times out (e.g. `TimeoutError` waiting for download events), the failure must also be logged to prevent silent errors and confusion.

## Token Scarcity, Quota Exhaustion & Model Fallbacks
- **The Issue**: When the user's high-tier models (Pro) hit quota limits, the environment automatically transitions to lower-tier models (such as Gemini Flash).
- **The Impact**: Flash models have smaller reasoning context bounds and are more prone to minor syntax oversights, missing closing brackets, or detached block structures. For example, a property observer (`didSet`) was accidentally detached and left floating in `TimelineViewModel.swift`, which caused compiler crashes.
- **Mitigation**: 
  - Do not make massive sweeping code refactors in a single step under Flash constraints.
  - Keep changes highly localized, small, and surgical.
  - Eagerly run `compile_applet` or linter checks after EVERY single change to catch syntax regressions early.
  - Manually review all changed closures, bracket nesting, and Swift structure initializers before committing.

## Tool Quota Efficiency & Batching
- **Optimization Rule**: To minimize discrete system runs and prevent hitting token or execution rate limits, always batch file reading and diagnostics.
- **Practice**:
  - Prefer using a single broad `grep` query or multi-file diagnostic check over multiple individual `cat` or `view_file` calls.
  - When applying multiple non-adjacent edits, use the `multi_edit_file` tool rather than running several consecutive `edit_file` calls.
  - Leverage parallel background commands for independent operations where the output of one is not needed for the next.

## Toolbar Buttons Collapsing into Broken Ellipsis Menu
- **Observation**: Wrapping dynamic/conditional toolbar buttons (e.g. stream toggle, hide-read-posts) in `ToolbarItemGroup(placement: .topBarTrailing)` causes SwiftUI to sometimes group them into a non-functional `...` overflow menu instead of showing them directly.
- **Solution**: Don't use `ToolbarItemGroup` for this. Emit each button as its own `ToolbarItem(placement: .topBarTrailing)` conditionally from a `@ToolbarContentBuilder` property instead — each item only appears in the toolbar when active, and none of them get swallowed into an overflow menu.

## Tag Groups Feature Architecture
- **Data Model & Persistence**: Tag groups use a SwiftData `@Model` (`TagGroup`), allowing `@Query` to keep the UI in sync automatically.
- **Model ↔ Timeline Filter Decoupling**: The app decouples the SwiftData `TagGroup` model (in the `Models` package) from the `TimelineFilter.tagGroup` enum (in the `Timeline` package). The Timeline package has no SwiftData dependency. the app layer copies data between them.
- **Two Persistence Paths**: SwiftData stores the group, while `@AppStorage("timeline_pinned_filters")` stores pinned filters via `TimelineFilter`'s `Codable`. Editing a group in SwiftData does *not* automatically update a pinned filter copy, which is a potential staleness gotcha.

## Mastodon API: Tag Group Searching & Hash Sanitization
- **Limitation**: The Mastodon API `any[]` array query for `Timelines.hashtag` acts as a server-side OR merge, but it seems to limit or miss results compared to doing separate full text searches.
- **Solution**: For tag groups (which contain multiple hashtags), it's more reliable to fetch each tag individually using separate API calls (`Timelines.hashtag(tag: cleanTag)`) and merge the results client-side, filtering out duplicates using a Set of Status IDs. This approach ensures a comprehensive list of statuses is retrieved.
- **Mastodon API Hash Symbol Encoding**: When hitting `/api/v1/timelines/tag/:hashtag`, the hashtag must NOT include the `#` symbol. If `#` is included in the Swift `URLComponents.path`, it can either truncate the path (acting as a fragment) causing 404s, or encode as `%23`. While Mastodon core strips `%23` in `any[]` parameters, some forks and older versions do not, leading to silent filtering (0 matches for the encoded tag). Always sanitize and strip `#` from tag queries before sending them to the Mastodon API.
- **Don't fan out concurrent requests per tag**: Firing one concurrent API request per hashtag in a tag group (e.g. 10 simultaneous requests for a 10-tag group) to work around the `any[]` limitation is effectively a mini-DDoS against the instance and was reverted. Fetch/merge individual tags, but do it without blasting an instance with a burst of parallel requests — throttle or serialize the calls instead.

## Client-Side Tag Group Merging & Data Loss
- **Bug**: Client-side merging of timelines (like Tag Groups) combined results from multiple API calls and truncated them using `.prefix(limit)` to match standard pagination counts.
- **Consequence**: This permanently dropped statuses because Mastodon's `minId`/`sinceId`/`maxId` Snowflake pagination creates invisible gaps when valid statuses within the bounds are thrown away by the client. The unread pill count was always too low, and hiding seen posts resulted in blank timelines.
- **Fix**: Never truncate combined pagination results when utilizing client-side merges. Let the SwiftUI list handle the bulk data instead of creating dropped-packet gaps.

## 🚨 Exit Code 65 & Compiler Error Mitigation
- **Exposed Properties on UserPreferences**: `UserPreferences` in the `Env` package uses a nested `Storage` class with `@AppStorage` wrappers to handle UserDefaults. When adding new settings (like `tagGroupsClientSideMergeEnabled` or `undoScrollToTopEnabled`), adding them only to the `Storage` class is insufficient. You must also expose a matching `public var` on the main `UserPreferences` class itself (with `didSet` propagating to `storage`) AND ensure the initial value is synced back from `storage` inside the `init()` method. Failure to do so will result in a compiler failure (Exit Code 65) when other files attempt to access it.
- **Default Initializers in Structs**: Adding properties to an existing struct (e.g. `TimelineContentFilter.Snapshot`) without providing default values inside the struct's custom initializers will break all existing instantiations, particularly in independent test targets (`TimelineViewModelTests.swift`). Always specify sensible defaults (e.g., `isGalleryMode: Bool = false`) in struct initializers.
- **Swift String Interpolation safety**: Never escape quotes inside Swift string interpolations. Swift 5+ supports unescaped quotes naturally. Writing `\"%.1f\"` will cause compiler crashes (Exit Code 65). Always write `%.1f` directly without backslash-escaping double-quotes.
- **`@ViewBuilder` control flow**: You cannot place arbitrary Swift control flow statements (standard `for` loops or complex `switch` logic that mutates local arrays) directly inside a function or property marked `@ViewBuilder`. Extract that logic into a local closure that returns the final array, then use `ForEach` inside the `@ViewBuilder` to render the UI.

## Phanpy-Style Boost Carousel Architecture
- **Background**: Phanpy groups multiple consecutive boosts (reblogs) from different accounts into a single, horizontally scrollable carousel to prevent the home timeline from becoming cluttered with a "wall of boosts."
- **Implementation Rules**:
  - **Data Structure**: Group adjacent boosted statuses into a `.boostCarousel` item in the `TimelineItem` enum with a unique ID computed from the first status ID.
  - **Processing Pass**: Iterate through incoming statuses in `TimelineDatasource` and collapse sequences of reblogs. This is best handled as a view-level transformation on the active timeline data source to avoid caching complexities.
  - **UI Carousel Layout**: Use `ScrollView(.horizontal, showsIndicators: false)` wrapping a `LazyHStack` with view-aligned scroll target behavior. Frame elements to taking up roughly 85% of screen width to hint at horizontal scroll availability. Ensure `.onAppear` and `.onDisappear` triggers on individual carousel rows fire correctly so unread tracking doesn't break.
  - **User Configuration**: Provide a toggle in `UserPreferences` (and Settings UI) so users can opt back into the traditional vertical layout.

## Scroll-to-Top Undo State Tracking
- **Observation**: When a scroll-to-top trigger is initiated, the list immediately scrolls up, changing `scrollToTopVisible` to `false` when it reaches the top.
- **Fix**: To allow a secondary tap to undo/scroll back to the previous offset, the check must expect `!scrollToTopVisible` (at the top) along with `previousScrollPosition != nil`. Checking `scrollToTopVisible` itself on the second tap would fail since the list has already finished scrolling up.

## IceShrimp.NET List Retrieval Compatibility
- **Observation**: The `GET /api/v1/accounts/:id/lists` endpoint is prone to failure or missing implementation on IceShrimp instances.
- **Fix**: A robust workaround is fetching all lists and individually fetching the accounts of each list (`Lists.accounts(listId:)`) via a Swift task group.

## Dual Gallery Mode Context Menu Architecture
- **Timeline/List Gallery (`GalleryStatusesListView` / `GalleryMediaCell`)**: Configured with a `.contextMenu` loading `StatusRowContextMenu`. This displays full Mastodon interactions (boost, fave, reply, delete, etc.) since cells in these flows represent distinct posts in a feed. Originally implemented in commit `814a0caf`.
- **Profile Media Grid Gallery (`AccountDetailMediaGridView`)**: Configured with a lightweight, media-focused `.contextMenu` containing specific media tools (Open Media via QuickLook, Share Link, Copy Image/Link) rather than timeline operations. Updated in commit `bb685fef` to support fallback/force remote media loading.
- **Avoid Overlap Confusion**: Because these views are in separate modules (`StatusKit` and `Account`), changes to expose/refactor cell visual layers (like making `GalleryMediaCell` public in commit `14a03ed4` for full-width layout support) do not replace or break the distinct context-menu capabilities of the respective gallery implementations.

## Profile Media Tab vs. Full-Screen Media Grid Implementations
- **Profile Media Tab (`MediaTab.swift` / `MediaTabView`)**:
  - **Location**: `/Packages/Account/Sources/Account/Detail/Tabs/MediaTab.swift`
  - **Purpose**: Displays a native, inline feed tab on the user's profile detail view.
  - **Layout**: It renders a standard, vertical list of posts containing media using `AnyStatusesListView` to map out full `StatusRowExternalView` cards.
  - **Navigation**: To allow full grid browsing, it includes a tap-to-navigate row header styled with `Image(systemName: "square.grid.2x2")` reading "Media Grid" that pushes to the full-screen media grid.
- **Full-Screen Media Grid (`AccountDetailMediaGridView.swift`)**:
  - **Location**: `/Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift`
  - **Purpose**: A dedicated full-screen 3-column masonry grid layout.
  - **Layout**: Renders high-density thumbnail images/videos inside a `LazyVGrid` wrapper.
  - **Navigation**: Pushed either from the "Media Grid" row in `MediaTab`, or via the `square.grid.3x3` toolbar icon on the main user profile header.
- **Future Alignment**: These two layouts manage media fetch, fallback state, and display modes separately. Identifying their structural files prevents accidental overlaps and provides a roadmap for downstream codebase unification.


## REST Pagination Safety & Capped Timelines (e.g. Lists)
- **Problem**: When a server caps page results (e.g. at 20 items) but the app expects a higher page limit (e.g. `Constants.nextPageLimit = 40`) to keep paging, a check like `lastCount < nextPageLimit` will evaluate to `true` on the very first page fetch. This sets `nextPageState` to `.none`, permanently disabling scrolling/paging for that timeline.
- **Solution**: The safest and most standard way to detect the end of a paginated timeline is checking if the fetched status list is empty, i.e. `newStatuses.isEmpty || lastCount == 0`. This allows continuous paging on custom lists, hashtags, or server-limited timelines regardless of their hard page limits.

## Modular Component Reuse Across Packages
- **Unifying Custom Layouts**: Relying on duplicate implementations of high-density grid layouts (such as `AccountDetailMediaGridView` vs `GalleryStatusesListView`) invites divergent bugs where one layout falls behind on performance improvements, seen-state tracking, custom column preferences, or rich interactions.
- **Implementation**: Instead of maintaining two separate gallery grids, refactor the custom views to be a fullscreen ScrollView container wrapping the standard `GalleryStatusesListView` from `StatusKit`.
- **Fetcher-Conforming Wrappers**: By creating a lightweight, conforming `StatusesFetcher` wrapper (`AccountMediaFetcher`), we can bridge the `Account` package and the `StatusKit` package, feeding the modular layout with custom paginated list queries while respecting all the user's customized column/crop preferences out of the box.

- **Scroll Tracking in SwiftUI Lists**: When tracking visible items using `.onAppear` and `.onDisappear`, inserting into a flat array (`insert(at: 0)`) only tracks chronological appearance order. To find the true spatial top-most visible item, you must iterate over your ordered datasource and find the first item whose ID currently exists in the tracked visible set.
- **Status Bar Tap Conflicts**: When using an overlay `UIWindow` to intercept status bar taps, returning `nil` in `hitTest` allows the system to also process the tap and perform native scroll-to-top. Any manual `proxy.scrollTo` triggered concurrently while the user is *not* at the top will aggressively fight the native scroll animation. Manual scroll-to-top undo must strictly only execute when the user is *already* at the top.

## Complete Experimental Settings Localization
- **Observation**: Adding new features and settings in English under `Localizable.xcstrings` without corresponding translations for other supported languages causes non-English users to see raw localization identifier keys (like `settings.experimental.title`) in the UI.
- **Solution**: Always supply comprehensive native localizations for all new UI keys in all 19 supported languages to preserve a polished user experience regardless of the user's active device locale.

## Managing CI/CD Automated Triggering
> Note: Builds are started manually from the Codemagic UI — not on push.
- **Observation**: Automatic CI build triggers (a `push` event under Codemagic's `triggering` block in `codemagic.yaml`) run compile routines on every commit, creating substantial workflow clutter and spamming failed/incomplete build notices during highly iterative developer turns.
- **Solution**: Automated push triggers are commented out/deactivated in `codemagic.yaml`. Builds are run on-demand, manually, from the Codemagic UI — never assume a push will trigger a build.

## Scroll-to-Top Undo Gesture Conflict & ID Resolution
- **Observation**: Tapping the status bar on iOS triggers a native UIKit scroll-to-top gesture on any active scroll views. If a manual scroll-to-bottom/undo animation is triggered at the exact same moment on a status bar tap when already at the top, the UIKit layout engine and SwiftUI's `ScrollViewProxy` fight, and UIKit's gesture cancels the SwiftUI animation.
- **Solution**: Execute the `proxy.scrollTo` action via state change (`scrollToIdAnimated`) triggered inside a tiny `0.1`-second delayed block on the main runloop (`DispatchQueue.main.asyncAfter`). This allows the native UIKit gesture event loop to finish its status bar tap processing before we fire our SwiftUI scroll-down animation, avoiding the conflict.
- **Strict Concurrency Safety (Exit Code 65 Prevention)**: `ScrollViewProxy` is NOT `Sendable`. According to Apple documentation, "The proxy is valid only within the content closure of a ScrollViewReader. Don't store a proxy or pass it to asynchronous code." Capturing `proxy` directly inside `DispatchQueue.main.asyncAfter` inside a ViewModel will cross isolation boundaries and trigger strict concurrency compiler crashes (Exit Code 65). Always return the target ID from the ViewModel and use a `@State` / `@Binding` variable evaluated synchronously inside a SwiftUI `.onChange` view modifier to interact with the proxy.
- **Observation 2**: Setting a sentinel top view's height to `0` when filters are active can cause SwiftUI to optimize the view out of the layout hierarchy or consider it non-rendered, which breaks its `.onAppear`/`.onDisappear` triggers and leaves `scrollToTopVisible` permanently `false`.
- **Solution 2**: Use a virtually invisible but renderable height of `0.5` points instead of `0`. This satisfies the layout system, ensuring `.onAppear`/`.onDisappear` work with absolute reliability while remaining invisible to the user.
- **Observation 3**: `ScrollViewProxy` can fail to locate scroll targets if items inside a `ForEach` or custom container structures are missing explicit `.id(...)` modifiers, particularly when wrapped inside complex stacks or custom grid views.
- **Solution 3**: Always append explicit `.id(status.id)` or `.id(item.id)` modifiers to cell views inside list/grid feeds to ensure robust resolution by the scroll proxy.


## Concurrency-Safe Undo Timers in SwiftUI
- **Observation**: Using standard `Timer.scheduledTimer` within highly isolated `@MainActor` structs or closures can occasionally trigger strict Swift 6 Sendable/Concurrency warnings or crashes (Exit Code 65).
- **Solution**: To implement timeouts natively in SwiftUI views (like our undo-scroll-to-top timers), always prefer `Task { try? await Task.sleep(for: .seconds(timeout)) }` managed via an `@State private var undoTask: Task<Void, Never>?`. This cleanly inherits the surrounding actor context and safely mutates `@State` properties upon completion without escaping boundaries.
- **Dynamic Tab ID resolution in SwiftUI**: When building highly customizable TabViews, do not hardcode list identities to static enumerations (e.g., `newValue == 0`). Instead, inject an environment variable (like `@Environment(\.currentTabId)`) at the `Tab` builder level. The underlying lists should compare any global tap pulses against this contextual environment variable, cleanly supporting arbitrary tab shuffling and duplicated view types (like multiple `TimelineListView` tabs).


## Trending Algorithm Investigation
Based on Mastodon's open-source Ruby on Rails codebase (`app/models/trends/statuses.rb`), the server-side trending algorithm for statuses calculates a score that decays over time.

### The Algorithm
1. **Base Metric**: `observed = reblogs_count + favourites_count`.
2. **Threshold**: If `observed` is less than a minimum threshold (default `5`), the score is `0`.
3. **Raw Score**: It uses a chi-squared style formula: `score = ((observed - expected)^2) / expected`. 
   - `expected` is hardcoded to `1.0`.
   - This simplifies to `(observed - 1)^2`.
4. **Time Decay**: The score undergoes exponential decay based on a half-life.
   - Default half-life is `1 hour`.
   - `decaying_score = score * (0.5 ^ (hours_since_creation / score_halflife))`.
   - This means a post's score drops by half every hour since it was created.

### Eligibility Requirements
A status is only eligible for trending if:
- It is public.
- The author's account is discoverable and not silenced.
- It does not contain sensitive content (or spoiler text).
- It is not a reply.

### Client-Side Implementation considerations (e.g. for IceShrimp)
To implement a "Trending" workaround on the client side:
- We can fetch the Local Timeline (or federated timeline) and score statuses based on the Mastodon algorithm.
- Variables like `threshold` and `score_halflife` should be configurable.
- Sort the statuses by `decaying_score` descending.
## Gallery Mode: Trials & Tribulations
> Gallery Mode's masonry grid has been the single most iterated-on, reverted-on part of this codebase. These are grouped together because several "fixes" were themselves undone once they caused a different regression — read the whole section before touching this layout again.

### Chunking the Grid — Don't
Segmenting the masonry grid into chunks (`makeSegments` / `GallerySegment.grid`/`.gap`) was tried twice (2026-07-20, and accidentally reintroduced 2026-07-21) and reverted both times because it caused severe visual layout gaps, images spanning out of columns, and vertical jittering on load.
- **Correct, current solution**: Keep the masonry grid as a **single, continuous** `HStack` of columns — this is the "gold standard" layout. Represent items with a `GalleryItem` enum (`.media(MediaStatus)` / `.gap(TimelineGap)`) and force `.gap` items into column 0 as normal items in the flow, rendered via `TimelineGapView`. Wrap this single masonry `HStack` inside the *outer* `LazyVStack` (in `TimelineListView`/`AccountDetailMediaGridView`), not per-chunk lazy containers — that outer laziness alone is what prevents the grid from evaluating until scrolled into view.

### Nested Lazy Containers Break Height Calculation
- **Observation**: Placing `LazyVStack` inside an `HStack` inside another lazy container (like a `List` or `ScrollView`) completely breaks SwiftUI's height calculation logic, especially when children contain asynchronously loaded media (like `LazyImage`). Users see massive, inexplicable gaps between images.
- **Solution**: Always use a standard `VStack` for the columns of a masonry `HStack`, allowing the outer `List`/`ScrollView` to calculate the grid's total height as a single block. Inner items using `LazyImage` still load efficiently when entering the bounds.

### VStack Column Centering (The "Grid" Bug)
- **Observation**: In `HStack(alignment: .top)` with standard `VStack` columns, SwiftUI proposes the tallest column's height to the shorter ones. Without a trailing `Spacer`, shorter columns center their content vertically instead of staying packed at the top — rows end up magically aligning across independent columns, looking like a broken masonry.
- **Solution**: Add `Spacer(minLength: 0)` to the bottom of every column `VStack`. Also give loading placeholders `.aspectRatio(1, contentMode: .fit)` if they lack metadata, so they don't infinitely expand.
- **Related bug — `.fill` vs `.fit` on cropped images**: A "Crop to Square" option applying `.aspectRatio(1, contentMode: .fill)` inside one of these unconstrained-height columns makes SwiftUI propose an unbounded height and stretch the image to fill it, producing huge empty gaps below "square" images. Use `.fit`, not `.fill`.
- **Related bug — duplicate cell IDs**: A post with multiple media attachments needs each `GalleryMediaCell` keyed by the attachment's own ID, not the parent post's `status.id` — reusing the post ID across attachments causes SwiftUI view-identity conflicts that break layout and long-press/context-menu targeting.

### Multiple Media Attachments Per Post
- **Observation**: `status.asMediaStatus` returns an array `[MediaStatus]` — one entry per media attachment on that status.
- **Fix**: Treating it as a single element, or `compactMap`/`if let`-ing it, silently drops multi-attachment posts. Loop over `status.asMediaStatus` and expand each into its own `.media(MediaStatus)` item so every attachment renders independently in the grid.

### Zero-Height Anchor Items Collapsing LazyVStack
> This went through three iterations — the first two each caused a different bug. The solution below is the one that actually stuck.
- **Attempt 1 (wrong)**: Distribute consecutive zero-height spacer/"anchor" views (used to preserve chronological place for text-only posts) evenly across columns. One column could still accumulate too many anchors before its first real item, silently collapsing that column.
- **Attempt 2 (wrong)**: Filter zero-height anchor items out of the data source entirely. This fixed the collapse, but broke timeline place-saving — text-only posts vanished from the layout, so scroll position and "catch up" tracking lost their reference points.
- **Solution (current, correct)**: Don't render anchors as their own zero-height root-level items. Bundle each text-only anchor status into the same parent container (a `GalleryNode` struct) as the next media item that follows it — interspersed in order, without ever handing `LazyVStack` a run of consecutive zero-height root children.

### Pagination Stalls & Silent Failures
- **Sparse-media threshold stall**: An auto-fetch condition written as `mediaStatuses.count > 0 && mediaStatuses.count < 6` will stall forever if the very first fetched page has zero media items — `count > 0` is never true, so the fetch never starts. Use just `mediaStatuses.count < 6`.
- **Pagination trigger silently stops firing**: If the pagination sentinel (`NextPageView` / a manual `.task` trigger) sits inside a plain `ScrollView { VStack { ... } }`, SwiftUI evaluates it eagerly on mount — its `.task` fires once and never again once the user scrolls, so infinite scroll appears "stuck." Wrap the outer container in `LazyVStack` so the pagination view only instantiates once scrolled to.
- Prefer Design System's built-in `NextPageView` over a hand-rolled `.onAppear { Task { ... } }` row — it natively guards against concurrent duplicate fetches and ships a retry-on-failure UI.

### Long-Press Highlighting the Whole Grid
- **Observation**: Attaching `.contextMenu` to a whole `Button` styled with `.buttonStyle(.plain)` inside a nested `LazyVStack`/`HStack` masonry layout can cause a long-press to visually highlight every cell in the grid, not just the tapped one.
- **Fix**: Attach `.contextMenu` directly to the image `Group` inside the button's label (not the button itself), and add `.contentShape(.contextMenuPreview, Rectangle())` so the highlight anchors precisely to the tapped image.

### Unread "Catch-Up" Scroll Targeting — Unverified
> ⚠️ **IMPORTANT DISCLAIMER**: This entry represents the unverified analysis and opinion of a Gemini 3.5 Flash model due to Pro preview quota exhaustion. This hypothesis has NOT been compiled, run, or verified, and is highly likely to contain inaccuracies or be entirely incorrect. Do not execute or rely on this plan without extensive manual verification.
- **Observation**: Standard timelines use `Status.id` to store scroll positions and handle "catch up" scrolling (via the unread statuses button tap which modifies `scrollToIdAnimated`).
- **Root Cause (hypothesized)**:
  1. In `GalleryStatusesListView.swift`, cells are keyed with `mediaStatus.id` (the attachment ID), while trailing non-media posts are mapped to `anchorIds` (keyed with `status.id`). Any status with media is never registered under its parent `status.id`, so `ScrollViewProxy.scrollTo(statusId)` fails silently.
  2. In `TimelineListView.swift`, the unread statuses tap handler intercepts `scrollToIdAnimated` in Gallery Mode and forces a scroll to the top, completely bypassing the targeted catch-up status ID.
- **Solution Plan (unverified)**:
  1. Add a `statusId` optional property to `GalleryNode`, populated with `status.id` only for the first attachment (`index == 0`) of a media status.
  2. Bind `.id(node.statusId)` to the container `VStack` wrapping the cell in the masonry grid.
  3. Remove the Gallery Mode override in `TimelineListView.swift` so it uses the actual unread `statusId` (like List Mode) instead of forcing a scroll to the absolute top.

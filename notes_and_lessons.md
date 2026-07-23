# Notes and Lessons

## The `a-shell mini` Workflow for iOS Development
The primary development environment for this project is highly unconventional: writing Swift/SwiftUI for an iOS app from within AI Studio, entirely operated from an iOS device, using `a-shell mini` for version control.

**Why this is necessary:**
AI Studio's native GitHub push mechanism is destructive to complex Xcode projects. It ignores `.gitignore` rules, bloats the repo with binary files, and mangles file structures. We strictly avoid it.

**The Workflow:**
1. **Code Generation:** Modify the Ice Cubes source code here in AI Studio inside the isolated `/ios-workspace` sandbox.
2. **Export:** Use the web dashboard provided by the preview server to download just the `/ios-workspace` as a clean `.zip` archive.
3. **File Management:** Save the `.zip` directly into the `a-shell mini` folder in the iOS Files app.
4. **Git Operations (in `a-shell mini`):**
   - Unzip the downloaded archive.
   - Use `cp -a` or `rsync` to overwrite the files in your locally cloned Git repository.
   - Run `git add .`, `git commit`, and `git push`.
5. **Compilation:** The GitHub push triggers the `.github/workflows/ios-build-distribute.yml` Action, which produces an **unsigned** `.ipa`.
6. **Distribution (No Apple Dev Account):** Download the unsigned `.ipa` artifact from GitHub Actions and sideload it onto your device using **SideStore** or **AltStore** (SideStore is recommended for on-device refreshing without a computer).

**The Reality of the Feedback Loop:**
You are essentially "coding blind." You cannot run local Xcode previews. Every UI tweak or logic change requires downloading the isolated ZIP from the AI Studio web interface, pushing via `a-shell mini`, waiting 10-15 minutes for GitHub Actions to compile an unsigned `.ipa`, and sideloading it via SideStore. It is slow, but entirely possible to build and test native iOS apps directly from an iPhone without a Mac or a paid Apple developer account.

## GitHub Authentication in `a-shell mini`
Because `a-shell mini` cannot launch interactive web OAuth flows for Git, you must use a GitHub Personal Access Token (PAT) for HTTPS authentication.

**Step 1: Generate a Token**
1. Go to github.com in Safari and sign in.
2. Navigate to **Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
3. Click **Generate new token (classic)**.
4. Set an expiration and check the `repo` scope.
5. Generate and copy the token. Store it securely (e.g., Apple Passwords).

**Step 2: Clone the Repository in `a-shell mini`**
When cloning the repository for the first time, embed the token in the URL:
`git clone https://YOUR_USERNAME:YOUR_TOKEN@github.com/YOUR_USERNAME/YOUR_REPO.git`

**Step 3: Configure Git Identity**
Set up your global Git configuration so your commits are attributed correctly:
`git config --global user.name "Your Name"`
`git config --global user.email "your.email@example.com"`

**Step 4: Managing Token Caching (Optional)**
If you cloned via normal HTTPS without the token in the URL, `a-shell mini` will prompt you for a username and password upon `git push`. Enter your GitHub username, and paste the PAT as your password. You can tell Git to cache credentials temporarily so you don't have to paste the token every time:
`git config --global credential.helper store`

Using a PAT ensures you can smoothly pull, commit, and push from `a-shell mini` without being blocked by interactive authentication screens.

## ⚠️ Mobile Extraction False Positives
When working with source code within AI Studio and extracting it on an iOS device (`a-Shell mini`), there is a very high likelihood of Git detecting "false positive" modifications. 

These occur because standard iOS file extraction and basic `cp` commands do not respect UNIX file system nuances the way a native macOS/Linux environment would. The two biggest offenders are:

1. **File Permissions (`chmod`)**: `a-Shell mini` is a sandboxed iOS app. When you unzip files and copy them over, executable flags (like `100755` on shell scripts or binaries) are often wiped to `100644`. Git detects this as a file modification (`old mode 100755 new mode 100644`).
2. **Line Endings (CRLF vs LF)**: Sometimes, archiving and unarchiving text files across environments accidentally normalizes or converts line endings. If LF (`\n`) is converted to CRLF (`\r\n`), Git will flag the entire file as modified.

**The Fix:** We have hardcoded protective Git configurations into the `apply_and_push.sh` script to neutralize these threats before committing:
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

## Tag Groups Feature Architecture
- **Data Model & Persistence**: Tag groups use a SwiftData `@Model` (`TagGroup`), allowing `@Query` to keep the UI in sync automatically.
- **Model ↔ Timeline Filter Decoupling**: The app decouples the SwiftData `TagGroup` model (in the `Models` package) from the `TimelineFilter.tagGroup` enum (in the `Timeline` package). The Timeline package has no SwiftData dependency. the app layer copies data between them.
- **Two Persistence Paths**: SwiftData stores the group, while `@AppStorage("timeline_pinned_filters")` stores pinned filters via `TimelineFilter`'s `Codable`. Editing a group in SwiftData does *not* automatically update a pinned filter copy, which is a potential staleness gotcha.

## Mastodon API: Tag Group Searching & Hash Sanitization
- **Limitation**: The Mastodon API `any[]` array query for `Timelines.hashtag` acts as a server-side OR merge, but it seems to limit or miss results compared to doing separate full text searches.
- **Solution**: For tag groups (which contain multiple hashtags), it's more reliable to fetch each tag individually using separate API calls (`Timelines.hashtag(tag: cleanTag)`) and merge the results client-side, filtering out duplicates using a Set of Status IDs. This approach ensures a comprehensive list of statuses is retrieved.
- **Mastodon API Hash Symbol Encoding**: When hitting `/api/v1/timelines/tag/:hashtag`, the hashtag must NOT include the `#` symbol. If `#` is included in the Swift `URLComponents.path`, it can either truncate the path (acting as a fragment) causing 404s, or encode as `%23`. While Mastodon core strips `%23` in `any[]` parameters, some forks and older versions do not, leading to silent filtering (0 matches for the encoded tag). Always sanitize and strip `#` from tag queries before sending them to the Mastodon API.

## Client-Side Tag Group Merging & Data Loss
- **Bug**: Client-side merging of timelines (like Tag Groups) combined results from multiple API calls and truncated them using `.prefix(limit)` to match standard pagination counts.
- **Consequence**: This permanently dropped statuses because Mastodon's `minId`/`sinceId`/`maxId` Snowflake pagination creates invisible gaps when valid statuses within the bounds are thrown away by the client. The unread pill count was always too low, and hiding seen posts resulted in blank timelines.
- **Fix**: Never truncate combined pagination results when utilizing client-side merges. Let the SwiftUI list handle the bulk data instead of creating dropped-packet gaps.

## 🚨 Exit Code 65 & Compiler Error Mitigation
- **Exposed Properties on UserPreferences**: `UserPreferences` in the `Env` package uses a nested `Storage` class with `@AppStorage` wrappers to handle UserDefaults. When adding new settings (like `tagGroupsClientSideMergeEnabled` or `undoScrollToTopEnabled`), adding them only to the `Storage` class is insufficient. You must also expose a matching `public var` on the main `UserPreferences` class itself (with `didSet` propagating to `storage`) AND ensure the initial value is synced back from `storage` inside the `init()` method. Failure to do so will result in a compiler failure (Exit Code 65) when other files attempt to access it.
- **Default Initializers in Structs**: Adding properties to an existing struct (e.g. `TimelineContentFilter.Snapshot`) without providing default values inside the struct's custom initializers will break all existing instantiations, particularly in independent test targets (`TimelineViewModelTests.swift`). Always specify sensible defaults (e.g., `isGalleryMode: Bool = false`) in struct initializers.
- **Swift String Interpolation safety**: Never escape quotes inside Swift string interpolations. Swift 5+ supports unescaped quotes naturally. Writing `\"%.1f\"` will cause compiler crashes (Exit Code 65). Always write `%.1f` directly without backslash-escaping double-quotes.

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

## Masonry Grid Layout Bug (Nested Lazy Containers)
- **Observation**: Placing `LazyVStack` inside an `HStack` inside another lazy container (like a `List` or `ScrollView`) completely breaks SwiftUI's height calculation logic, especially when children contain asynchronously loaded media (like `LazyImage`).
- **Consequence**: Users will see massive, inexplicable gaps between images as the outer lazy container receives an unbounded or incorrect height calculation from the inner `LazyVStack`s resolving at different times.
- **Solution**: Always use standard `VStack` for the columns of a masonry `HStack`, allowing the `List` or `ScrollView` to correctly calculate the grid's total height as a single block. Inner items using `LazyImage` will still load efficiently when entering the bounds.

## Masonry Grid VStack Centering (The "Grid" Bug)
- **Observation**: When building a Masonry grid using `HStack(alignment: .top)` containing multiple standard `VStack` columns, SwiftUI's layout system will propose the height of the tallest column to the shorter columns. If the shorter `VStack`s contain only inflexible content or lack a trailing `Spacer`, they will center their content vertically within the proposed height, creating massive top and bottom gaps and unintentionally aligning rows across columns like a standard grid.
- **Consequence**: Users will report "vertical gaps" and state the "masonry seems completely broken" because rows magically align across independent columns.
- **Solution**: Always add a `Spacer(minLength: 0)` to the bottom of the `VStack` columns inside the `HStack(alignment: .top)`. This consumes the excess proposed height, pushing the inflexible content to the top and maintaining the tightly packed staggered look expected in a masonry layout. Additionally, ensure that loading placeholders (`ZStack` with `Color`) explicitly use `.aspectRatio(1, contentMode: .fit)` if they lack metadata, preventing them from infinitely expanding to fill available vertical space.

## Complete Experimental Settings Localization
- **Observation**: Adding new features and settings in English under `Localizable.xcstrings` without corresponding translations for other supported languages causes non-English users to see raw localization identifier keys (like `settings.experimental.title`) in the UI.
- **Solution**: Always supply comprehensive native localizations for all new UI keys in all 19 supported languages to preserve a polished user experience regardless of the user's active device locale.

## Managing CI/CD Automated Triggering
- **Observation**: Automatic CI build triggers (such as `push` events under Codemagic `triggering` in `codemagic.yaml` or `push` triggers in `.github/workflows/`) run compile routines on every commit, creating substantial workflow clutter and spamming developers with failed/incomplete build notices during highly iterative developer turns.
- **Solution**: Keep automated push triggers commented out or deactivated in `codemagic.yaml` and `.github/workflows` to prevent automatic compiles on intermediate/WIP commits. Active builds should be run on-demand via manual triggers (`workflow_dispatch` in GitHub or via Codemagic UI).

## Chunked Masonry Gallery feeds (Gaps & Laziness)
- **Observation**: Flattening a timeline state containing gaps into a single monolithic grid completely breaks two critical aspects of feed browsing:
  1. Gaps are discarded, so users cannot see or load missing statuses between historical positions and the top of the timeline (making it impossible to "scroll up past" the initial load point).
  2. All statuses are flattened into one giant parent view inside a non-lazy scroll container, prompting the system to run `onAppear` on all images simultaneously. This chokes Nuke's image downloading/rendering queues, causing many images to load endlessly.
- **Solution**: Segment the timeline `[TimelineItem]` stream into an array of distinct chunks (`grid` and `gap`). Within `GalleryStatusesListView`, render each contiguous grid chunk using a masonry `HStack` and each gap using `TimelineGapView` loader. Put these chunks inside a `LazyVStack` so that only the visible sections are evaluated, loaded, and requested at any one time.

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


## Multiple Media Status Representation in Gallery Mode
- **Observation**: `status.asMediaStatus` on `Status` returns an array `[MediaStatus]`, containing one entry for each media attachment attached to that status.
- **Fix**: In Gallery Mode, mapping statuses to items by treating `asMediaStatus` as a single element or using `compactMap` with `if let` drops multi-attachment posts or fails type checking. Expanding statuses into `.media(MediaStatus)` via a loop over `status.asMediaStatus` ensures every media attachment is rendered independently in the masonry grid, maintaining full context and interaction capability for each image/video cell.

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
-e ## 2026-07-23T19:30:23Z - SwiftUI LazyVStack Constraint Lesson
- **Lesson Learned**: Adding a large number of zero-height views (e.g. Color.clear.frame(height: 0)) consecutively at the top of a SwiftUI LazyVStack can cause the layout engine to collapse the entire stack, resulting in completely missing visual elements. Always distribute invisible placeholder anchors rather than clumping them together based on height calculations.
-e ## 2026-07-23T19:59:42Z - SwiftUI LazyVStack Constraint Lesson (Updated)
- **Lesson Learned**: Adding a large number of zero-height views consecutively at the top of a SwiftUI LazyVStack causes the layout engine to completely collapse that stack, rendering it invisible. Even distributing zero-height views across columns isn't sufficient if one column hits the limit before its first visible item. The only reliable solution is to completely filter out zero-height spacer items from the data source before rendering.

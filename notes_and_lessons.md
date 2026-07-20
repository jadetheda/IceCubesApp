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


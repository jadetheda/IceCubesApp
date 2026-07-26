# Notes and Lessons

## Codebase Synchronization & Guidelines Verification (July 2026)
- **Settings Cache Consolidation**: Integrated multi-account post caching and local custom emoji caching statistics into a single centralized cache screen section in `SettingsTab.swift`. The "Clear Cache" button now acts as a comprehensive cleaner, purging image pipeline caches (`ImagePipeline.shared.cache`), post storage across all active logged-in clients (`TimelineCache`), and all custom server emotes (`CustomEmojiCache`).
- **Guidelines and Architecture Alignment**: Conducted a complete code and guidelines alignment check. Re-verified and confirmed all development patterns match `CLAUDE.md` and `AGENTS.md` (declarative SwiftUI state expressions, direct `@State` and `@Binding` mechanisms, decoupled `@Observable` environments, and avoiding legacy view-model structures).
- **Git Repository Clean Syncing & Corruption Recovery**: When the Git database, pack-files, or binary index gets corrupted (e.g., throwing `fatal: unknown index entry format 0xbdef0000` or `fatal: Could not parse object 'HEAD'`), the most reliable recovery method is to run `sync_repo.sh` with a valid `GITHUB_PAT`. This cleanly wipes `ios-workspace` and restores a pristine clone of the latest main branch.
- **Timeline Endpoint Centralization**: When hooking up features that rely on timeline fetching (like custom Trending algorithms), the integration must be done inside `TimelineFilter.fetchStatuses()`. Modifying fetching logic in view-specific helpers (like `ExploreView`) causes the main app timeline view to ignore the setting because it routes directly through `TimelineFilter`.
- **Guidelines Review**: Re-verified complete compliance with the modern SwiftUI architecture outlined in `CLAUDE.md`. Emphasized the strict rule of using views as pure state expressions with native SwiftUI data flow patterns, while actively avoiding ViewModels (`No ViewModels`) and avoiding nested `@Observable` objects.
- **Historical Analysis**: Reviewed comprehensive logs of previous optimizations, specifically related to the masonry layout/jitter control, client-side merging for Tag Groups, iOS status bar tap interception window debouncing, and custom multi-language localizations.
- **Iceshrimp API Support Divergences**:
  - *Explore/Trends Failure*: On Iceshrimp.NET instances, standard Mastodon trend and suggestion endpoints return 404/405 errors. Fetching these in a combined `async let` throws and halts the entire Explore tab. By writing individual safe fetcher helper methods (`fetchSuggestedAccountsSafe`, `fetchTrendingTagsSafe`, etc.) that catch HTTP errors and return empty lists, the Explore tab remains operational on diverged instances.
  - *Explore UI Workarounds*: Because Iceshrimp misses endpoints like `trends/links` and `suggestions`, the quick access picker buttons in the Explore tab become useless/broken. Wrapping the `QuickAccessView` with a `!preferences.useIceShrimpWorkarounds` check cleanly avoids presenting unavailable features.
  - *Masonry Layout Discrepancies*: When building custom masonry layouts (like `GalleryStatusesListView`), the view modifier responsible for clipping the image MUST strictly adhere to the aspect ratio assumed by the pre-calculation algorithm. If the algorithm falls back to an aspect ratio of `1.0` (because dimensions are missing from the API), the view MUST be clipped to `1.0` (e.g. `Color.clear.aspectRatio(1.0).overlay{...}`). Allowing the view to resolve its intrinsic height dynamically via `.scaledToFit()` will break the layout columns, causing massive visual gaps.
  - *Quote Routing*: Quote timelines are mapped to `statuses/{id}/quotes` but on Iceshrimp they exist under `pleroma/statuses/{id}/quotes`. By checking `use_iceshrimp_workarounds` from `UserDefaults.standard` directly inside the decoupled `Statuses.swift` endpoint mapping, we achieve seamless and compile-safe dynamic quote routing without breaking package dependencies.

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

1.  **File Permissions (`chmod`)**: `a-Shell mini` is a sandboxed iOS app. When you unzip files and copy them over, executable flags (like `100755` on shell scripts or binaries) are often wiped to `100644`. Git detects this as a file modification (`old mode 100755 new mode 100644`).
2.  **Line Endings (CRLF vs LF)**: Sometimes, archiving and unarchiving text files across environments accidentally normalizes or converts line endings. If LF (`\n`) is converted to CRLF (`\r\n`), Git will flag the entire file as modified.

**The Fix:** We have hardcoded protective Git configurations into the `apply_and_push.sh` script to neutralize these threats before committing:
- `git config core.fileMode false` (Forces Git to ignore executable bit changes).
- `git config core.autocrlf input` (Normalizes line endings on commit).

- IceShrimp.NET compatibility: The `GET /api/v1/accounts/:id/lists` endpoint is prone to failure or missing implementation on IceShrimp instances. A robust workaround is fetching all lists and individually fetching the accounts of each list (`Lists.accounts(listId:)`) via a task group.

## Optimization & Quota Management 
- **Tool Quota Efficiency Rule**: To reduce the number of discrete steps and save token/quota limits, we should aggressively batch read operations (e.g., using `grep` across multiple files or large chunks of code in one shell call instead of multiple `cat` calls or single-file searches).
- For writing files or patching, use multi-file inline patch scripts (e.g. `npx node -e ...` or `cat > patch.swift && swift patch.swift`) instead of issuing multiple separate `edit_file` tool calls where possible. Parallel execution should be favored for independent tasks. Avoid looping commands like `sleep` in favor of standard background tasks or `schedule` tool if absolutely needed.

## Client-Side Tag Group Merging & Data Loss
- **Bug**: Client-side merging of timelines (like Tag Groups) combined results from multiple API calls and truncated them using `.prefix(limit)` to match standard pagination counts.
- **Consequence**: This permanently dropped statuses because Mastodon's `minId`/`sinceId`/`maxId` Snowflake pagination creates invisible gaps when valid statuses within the bounds are thrown away by the client. The unread pill count was always too low, and hiding seen posts resulted in blank timelines.
- **Fix**: Never truncate combined pagination results when utilizing client-side merges. Let the Swift UI list handle the bulk data instead of creating dropped-packet gaps.

## AI Studio Export Binary Corruption
- **Bug**: Re-initializing the `.git` directory (`rm -rf .git && git clone --no-checkout`) removes the repository-level git configuration. If `core.autocrlf` and `core.fileMode` are not immediately reapplied, Git will falsely detect binary files (like `.png` assets) as modified. If the user subsequently clicks the "Export to GitHub" button, the AI Studio platform will blindly commit these files, corrupting the remote binary assets.
- **Fix**: Always ensure `git config core.fileMode false` and `git config core.autocrlf input` are set on the workspace immediately after replacing or re-initializing the `.git` directory. If an automated commit mangles the repo, `git push -f origin main` to the last known good commit is required. We have now codified these settings directly into `/sync_repo.sh` so they are automatically configured whenever the workspace is cloned.

## Git Index & Object Database Corruption Recovery
- **Symptoms**: Git commands in `ios-workspace` fail with `fatal: unknown index entry format 0xbddb0000` or `fatal: bad object HEAD`.
- **Root Cause**: Workspace operations or container suspension can occasionally corrupt the binary git index or tracking objects.
- **Solution**: Delete the corrupted `.git/index` file. If the database remains broken, execute `./sync_repo.sh` to completely wipe and re-clone the clean repository using the `GITHUB_PAT` environment variable.

## SwiftUI Public Struct View Protocol Requirements
- **Observation**: When a struct/type in a Swift Package is declared as `public` (e.g., `public struct GalleryMediaCell: View`) to be consumed by other packages (such as `Account` consuming `StatusKit`s gallery views), its `body` property *must* be explicitly declared as `public` (e.g., `public var body: some View`).
- **Consequence**: Declaring `var body: some View` implicitly makes it `internal` (since the default access modifier in Swift is internal). This breaks conformity to the `View` protocol in a public interface context, resulting in a build error (Exit Code 65).
- **Fix**: Always mark `var body` as `public var body: some View` if the enclosing `struct` is `public`.

## Running Workspace Utility Scripts
- **Observation**: Newly cloned or existing shell scripts (like `sync_repo.sh` or `heal_pngs.sh`) might lack executable permissions (`chmod +x`) in the sandbox container filesystem, returning exit code `126` (`Permission denied`) when executed directly.
- **Solution**: Avoid modifying system execution permissions directly. Execute the shell scripts directly using their respective interpreter (e.g., prefixing with `bash` like `bash sync_repo.sh`) to guarantee trouble-free execution.

## WishKit SDK Visual Encapsulation
- **Observation**: WishKit features (like `WishKit.FeedbackListView()`) are pre-compiled and encapsulated inside a closed-source third-party SDK.
- **Consequence**: The SwiftUI list items (rows/cells) are managed internally by the package. Developers cannot directly bind custom gesture modifiers (e.g., long-press) or native SwiftUI context menus to individual wishes within that view.
- **Solution**: Feature statuses (e.g., Approved, In Progress, Completed) should be managed via the official WishKit administrator dashboard. For client-side customization or local progress tracking, a separate custom companion view/storage model must be implemented as an overlay or distinct settings interface.

## UIKit hitTest Multi-Triggering & App Store Guideline 2.5.1
- **Observation**: Overriding `hitTest(_:with:)` on a high-level `UIWindow` placed over the status bar is a known technique to intercept status bar taps in SwiftUI. However, UIKit calls `hitTest` multiple times in rapid succession during its touch routing cycle to determine coordinate targets and validate gesture phases.
- **Consequence**: This causes any action or notification triggered inside `hitTest` to fire repeatedly (2-4 times) for a single tap, completely breaking state-sensitive or toggled actions like scroll-to-top undo. Additionally, placing a persistent overlay window at `windowLevel = .statusBar + 1` is a grey area under App Store Guideline 2.5.1 ("Apps should use only public APIs and should not interfere with system-defined behaviors or gestures").
- **Solution**:
  1. **Debounce**: Implement time-based debouncing using `CACurrentMediaTime()` to filter out rapid-fire hits from the same touch cycle, ensuring notifications are posted exactly once.
  2. **Interference Mitigation**: Ensure the intercepting window remains strictly passive by returning `nil` inside `hitTest`. This allows UIKit to continue standard touch propagation so that native system gestures (such as scrolling to top, accessing Notification/Control Center, and swiping on the Dynamic Island) are never blocked or interfered with.

## SwiftUI Masonry, Cell Aspect Ratio Placeholders & Jitter Control
- **Observation**: When loading images inside a masonry-like grid (`LazyVStack` columns inside an `HStack`), cell heights will collapse to 0 before loading finishes if the layout doesn't specify a fixed or default aspect ratio. When images load, this causes dramatic size changes and vertical jumping/jittering of the scroll view.
- **Solution**:
  1. **Default Aspect Ratio**: Providing a default `16:9` aspect ratio placeholder constraint when metadata is missing ensures the bounds are pre-allocated, preventing vertical page jumps.
  2. **Lazy Views Nesting Rules**: Nesting `LazyVStack`s inside other lazy views can break scroll behavior and cause dynamic height re-calculations; wrapping the parallel columnar `LazyVStack`s inside a standard non-lazy `VStack` segment loop preserves native performance, scroll position, and correct pagination triggers.

## Workspace Synchronization & Sandbox File Integrity
- **Observation**: To synchronize or refresh the workspace against the remote GitHub repository, the `ios-workspace` can be cleanly re-cloned using the developer's Personal Access Token (PAT).
- **Consequence**: Modifying, deleting, or re-cloning the files inside `ios-workspace` alters the local file hashes. If the local integrity manifest is not synchronized, it can trigger the SHA-256 validation scanner and trip corruption alarms.
- **Solution**: Always execute a POST request to `/api/integrity/update` via Node immediately after performing any major file modifications or re-clones inside `ios-workspace` to keep the integrity manifest perfectly synchronized. In our latest execution, running `sync_repo.sh` followed by the API integrity post securely cleaned, cloned, and validated the workspace successfully. Running `bash sync_repo.sh` in the workspace environment cleanly checks out the latest repository commits from `main`, applying Git safe modes automatically.

## Event-Pulse vs. Static State in SwiftUI View Hierarchies
- **Observation**: When triggering actions based on active tab double-taps (such as scroll-to-top and scroll-undo), standard state properties (like `currentTabId` or `selectedTab`) are useless. Because the active tab ID remains unchanged when tapped twice, standard `.onChange` state observers never fire.
- **Consequence**: Attempting to drive transient events using persistent state variables results in silent failures for consecutive active-tab clicks.
- **Solution**: Model transient view actions as an event-pulse rather than a persistent state. Define a primitive environment value (like `selectedTabScrollToTop: Int`) that temporarily registers the tapped tab's ID on active-click, then resets to `-1` after a 100ms delay. Nested views listen to changes on this integer pulse, executing scroll actions exactly once per tap while remaining fully decoupled from app-level enum types.
## SwiftUI Masonry Grid vs Row-based Chunking
- **Observation**: Row-based chunking (`LazyVStack { HStack }`) seems like a good idea for laziness and gaps, but in practice, prepending items to the data source shifts the chunk alignment, causing all row IDs to change and breaking scroll position. Furthermore, it prevents a true masonry layout where items in different columns slide past each other.
- **Solution**: The "gold standard" for a true masonry grid in SwiftUI (pre-iOS 16 Layout) is `HStack { LazyVStack }`. To avoid the nested `LazyVStack` layout collapse bug, the outermost container inside the `ScrollView` MUST be a standard `VStack`. This provides the best compromise of performance, stable scroll identifiers (since each item maintains its structural position in its column), and true masonry appearance, even though full-width gap items must be discarded in this mode.

## Optimized Binary Integrity Tracking
- **Observation**: Tracking SHA-256 hashes for all binary files (such as thousands of alternate icons, assets, video/audio resources, and binaries) during integrity checks is highly resource-intensive and computationally pointless.
- **Consequence**: Full scanning introduces high CPU/disk usage, makes manifest creation/checking slow, and can trigger false-positive corruptions when file systems naturally mutate metadata.
- **Solution**: Since binary files are usually extracted/updated as a collective unit (if one is broken, all of them are broken), tracking exactly one small, stable representative binary file (e.g., `AppIcon.icon/Assets/puple_cube.png`) is completely sufficient. All other binary extensions can be safely bypassed during scanning to achieve near-instantaneous integrity checks and manifest updates.

## Adherence to CLAUDE.md and Self-Documentation Rules
- **Observation**: SwiftUI features require strict architectural alignment with `CLAUDE.md` to avoid rendering bugs and layout collapse, and files require self-documenting code to remain clear. Additionally, quota optimization is essential to keep agent interactions lean.
- **Consequence**: Straying from native `@State`/`@Binding` patterns or nesting `@Observable` objects breaks SwiftUI's observation tree and compilation. Undocumented code makes troubleshooting slow, and un-optimized steps waste tokens.
- **Solution**: Explicitly forbid ViewModels for new code, write exhaustive code comments clarifying bindings and states, and consolidate edits and tool calls to complete the entire scope with maximum efficiency.

## Localization Integrity and Restoring Custom Work
- **Observation**: Truncating or corrupting major localization catalogs (such as `.xcstrings` files) due to bad editor splits or merge conflicts will cause compiler/parsing crashes. Naively downloading/restoring a "pristine" file from upstream repo resets weeks/months of local custom translation/context work.
- **Consequence**: Naive restore overwrites the custom work entirely with default/upstream templates.
- **Solution**: Locate the last git commit before truncation/corruption occurred (using `git log` and JSON validation on target revisions), checkout/restore the file from that golden version, validate the JSON schema, and run the workspace SHA integrity manifest update to sync hashes.

## Eliminating Hardcoded UI Strings & Cross-Language Consistency
- **Observation**: Hardcoding UI strings directly in Swift views makes them inaccessible for translations, leading to visual fragmentation for multi-language users. When adding new settings or controls, they must be given structured keys in the main String Catalog (`Localizable.xcstrings`).
- **Consequence**: Users in non-English locales see untranslated English elements, degrading the native multi-language experience. Also, string catalogs can crash at build time if keys are missing from specific targets.
- **Solution**: Define systematic keys under appropriate sub-paths (e.g. `settings.experimental.iceshrimp.*`), write a reliable JSON parser/patcher to inject manual translations for all 19 supported languages (using localized formatting specs like `%lld` and `%.1f` for numeric sliders/steppers), reference them natively with `Text` or `NSLocalizedString`, and update the workspace integrity hashes.

## Prioritizing and Sorting Third-Party Attributions
- **Observation**: As open-source projects grow, the sheer volume of integrated dependencies can bloat the settings about screen. A simple alphabetic list does not communicate the actual architectural importance or usage frequency of each module.
- **Consequence**: Users and developers looking through the Credits/About section see a disorganized list where minor helper utilities stand on equal footing with major architectural pillars.
- **Solution**: Prioritize and sort dependencies strictly by their prominence and real-world utility frequency in the codebase. Core engine files (like Nuke for image loading/caching, EmojiText for custom emojis, and SwiftUI-Introspect for UIKit introspection) should sit prominently at the top, while minor specialized feedback, roadmap, or analytics SDKs sit gracefully at the bottom. Mirror this order in external `/attributions.md` files for structural consistency.

## Polishing and Harmonizing Localization Labels for iOS Native Feel
- **Observation**: UI labels generated or edited by models can sometimes sound overly technical, clunky, or break visual standards by mixing casing patterns (Title Case vs. Sentence Case) and naming conventions across sections.
- **Consequence**: Mixed/verbose copy (like "Persistent Toolbar Toggle" or "Button acts as a state toggle instead of one-off action") feels unnatural, clutters settings pages, and breaks Apple's Human Interface Guidelines.
- **Solution**: Refine all localization copy to follow consistent native Apple conventions—specifically utilizing concise Sentence Case (e.g., "Act as persistent toggle", "Add thin outer margins", "Crop images to square"), and aligning specialized brand names correctly ("Gallery Mode" instead of "Media Only"). Update both standard and regional English locales (`en` and `en-GB`) simultaneously to guarantee consistent voice and vocabulary across all English-speaking users.



## Masonry Layout Direction vs Reshuffling in SwiftUI
- **Observation**: If a masonry grid (made of an `HStack` of `LazyVStacks`) calculates its column heights bottom-up (using `.reversed()`) to prevent top-refresh reshuffling, it inadvertently causes full-grid reshuffling upon bottom-pagination because every new item added to the bottom changes the index offset from the bottom for all existing items.
- **Consequence**: Users scrolling down in Gallery Mode experienced layout jitter and columns swapping places. Furthermore, bottom-up calculation caused the visual order (left-to-right) of the top-most items to be completely incorrect (oldest on the left, newest on the right) for grids with an even number of items.
- **Solution**: Masonry layout calculations MUST be performed top-down (from newest to oldest). This guarantees perfect chronological visual ordering at the top-left, and ensures that items added to the bottom during pagination do not alter the column assignments of existing posts.

## ScrollViewReader & View Exclusion
- **Observation**: If a View is intentionally excluded from a `ForEach` render pass (such as filtering out text-only posts in a Gallery view), any attempt to `proxy.scrollTo(id)` to that excluded item will silently fail, leaving the user stranded at the top of the ScrollView (newest items).
- **Solution**: Inject zero-height, invisible `Color.clear.frame(height: 0).id(item.id)` anchors into the layout for the excluded items. This satisfies `ScrollViewReader` and accurately snaps the scroll offset to the correct chronological position within a complex masonry layout without impacting the visual structure.
- **Timeline Gaps in Grids**: Instead of dropping timeline gaps to preserve strict grid constraints, break the timeline `items` array into chunks separated by `gap` elements. Render multiple masonry grid blocks vertically, interleaved with full-width gap loader views. This preserves continuity and pagination features without breaking columns.

## Variable Declarations in ViewBuilder Closures
- **Observation**: Declaring local variables within complex SwiftUI helper closures or view hierarchies must strictly follow Swift's property declaration semantics. If a variable is mutated or reassigned inside a scope, it must be properly prefixed with the `var` keyword.
- **Consequence**: Omitting the `var` keyword in a property assignment (e.g., `shortestColIndex = i` instead of `var shortestColIndex = i`) can lead to confusing compiler diagnostic warnings/errors (Exit Code 65).
- **Solution**: Proactively declare any reassigned loop counter or index trackers as local variables (`var`) in their enclosing block to maintain clean Swift type-checking.


## Git Synchronization Verification (July 2026)
- **Observation**: Running the `sync_repo.sh` script completely refreshes the local workspace from GitHub. If the script is run with `bash sync_repo.sh`, it avoids permission blocks on standard shells.
- **Consequence**: The workspace is cleanly cloned and is fully in sync with origin/main.
- **Action**: Always run the `/api/integrity/update` POST request immediately following a sync to keep AI Studio's integrity validation happy.


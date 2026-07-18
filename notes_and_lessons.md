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

1.  **File Permissions (`chmod`)**: `a-Shell mini` is a sandboxed iOS app. When you unzip files and copy them over, executable flags (like `100755` on shell scripts or binaries) are often wiped to `100644`. Git detects this as a file modification (`old mode 100755 new mode 100644`).
2.  **Line Endings (CRLF vs LF)**: Sometimes, archiving and unarchiving text files across environments accidentally normalizes or converts line endings. If LF (`\n`) is converted to CRLF (`\r\n`), Git will flag the entire file as modified.

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

## Tag Groups Feature Architecture & Lessons

Based on the recent PR detailing the Tag Group feature:

### Data Model & Persistence
- **SwiftData over AppStorage**: Tag groups use a SwiftData `@Model` (`TagGroup`), allowing `@Query` to keep the UI in sync automatically.
- **Model ↔ Timeline Filter Decoupling**: The app decouples the SwiftData `TagGroup` model (in the `Models` package) from the `TimelineFilter.tagGroup` enum (in the `Timeline` package). The Timeline package has no SwiftData dependency. The app layer copies data between them.
- **Two Persistence Paths**: SwiftData stores the group, while `@AppStorage("timeline_pinned_filters")` stores pinned filters via `TimelineFilter`'s `Codable`. Editing a group in SwiftData does *not* automatically update a pinned filter copy, which is a potential staleness gotcha.

### Network & Backend Integration
- **Server-Side Merge (`any[]`)**: A tag group maps to a Mastodon `/api/v1/timelines/tag/{firstTag}?any[]={second}&any[]={third}...` request. The `any[]` parameter is the core trick—Mastodon natively processes it as an OR query over multiple hashtags. No client-side merge logic is needed.
- **No Streaming**: Tag groups fall into the `.pub` filter context and are not in the streamable set, meaning no live WebSocket updates (manual refresh only).

### UI & Validation Rules
- **Validation**: Requires a non-empty title, a valid SF Symbol checked against `SFSafeSymbols`, and a minimum of 2 tags (a 1-tag group would just duplicate the standard hashtag timeline).
- **Lowercase on Save**: Tags are lowercased before persisting because Mastodon API calls are case-insensitive.
- **Identity Excludes Icon**: `TimelineFilter.tagGroup`'s `id` is computed from `title + tags.joined()`. Changing only the icon won't reload the timeline.

## Mastodon API: Tag Group Searching
- **Limitation**: The Mastodon API `any[]` array query for `Timelines.hashtag` acts as a server-side OR merge, but it seems to limit or miss results compared to doing separate full text searches.
- **Solution**: For tag groups (which contain multiple hashtags), it's more reliable to fetch each tag individually using separate API calls (`Timelines.hashtag(tag: cleanTag)`) and merge the results client-side, filtering out duplicates using a Set of Status IDs. This approach ensures a comprehensive list of statuses is retrieved.
- **Mastodon API Hash Symbol Encoding**: When hitting `/api/v1/timelines/tag/:hashtag`, the hashtag must NOT include the `#` symbol. If `#` is included in the Swift `URLComponents.path`, it can either truncate the path (acting as a fragment) causing 404s, or encode as `%23`. While Mastodon core strips `%23` in `any[]` parameters, some forks and older versions do not, leading to silent filtering (0 matches for the encoded tag). Always sanitize and strip `#` from tag queries before sending them to the Mastodon API.

## 🚨 Exit Code 65: Missing Exposed Properties on UserPreferences
* **The Root Cause**: `UserPreferences` in the `Env` package uses a nested `Storage` class with `@AppStorage` wrappers to handle UserDefaults. When adding new settings (like `tagGroupsClientSideMergeEnabled`), adding them only to the `Storage` class is insufficient.
* **The Solution**: You must also expose a matching `public var` on the main `UserPreferences` class itself (with `didSet` propagating to `storage`) AND ensure the initial value is synced back from `storage` inside the `init()` method. Failure to do so will result in a compiler failure (Exit Code 65) when other files attempt to access it via `UserPreferences.shared`.

## Phanpy-Style Boost Carousel Architecture

**Background:** Phanpy groups multiple consecutive boosts (reblogs) from different accounts into a single, horizontally scrollable carousel to prevent the home timeline from becoming cluttered with a "wall of boosts."

**Implementation Considerations & Steps:**

1.  **Data Structure Modification (`TimelineItem`)**:
    - Add a new case to the `TimelineItem` enum: `case boostCarousel([Status])` or `case boostCarousel(id: String, statuses: [Status])` to group adjacent boosted statuses.
    - Update the `id` property to return a unique identifier for the carousel (e.g., `"carousel-\(firstStatus.id)"`).

2.  **Processing Logic (`TimelineDatasource`)**:
    - Introduce a processing pass inside `TimelineDatasource` whenever items are updated (`set(items:)`, `append(items:)`, etc.).
    - Iterate over the incoming statuses and identify sequences of consecutive statuses where `status.reblog != nil`.
    - Collapse these sequences into a `.boostCarousel` item.
    - *Edge Case*: Only merge boosts if they appear adjacently in the timeline's strict chronological or paginated order.
    - *Staleness*: Consider how the timeline cache saves items; the `TimelineCache` will also need to support decoding/encoding the new `.boostCarousel` type, or the carousel grouping should remain purely a view-level transformation on the data source.

3.  **UI Rendering (`StatusesListView`)**:
    - In `StatusesListView.swift` (inside the `.displayWithGaps` switch case), handle `case .boostCarousel(let statuses):`.
    - Render a horizontally scrolling list:
      ```swift
      ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 16) {
              ForEach(statuses) { status in
                  StatusRowView(...)
                      .frame(width: UIScreen.main.bounds.width * 0.85)
              }
          }
          .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      ```
    - Ensure `.onAppear` and `.onDisappear` triggers on individual items within the carousel still fire correctly so `TimelineViewModel` can track `latestSeenId` correctly.

4.  **User Preference Toggle**:
    - Add `@AppStorage("boost_carousel_enabled") public var enableBoostCarousel: Bool = false` to `UserPreferences`.
    - Expose this setting in `SettingsTab` (under Timeline settings) so users who prefer the traditional vertical layout can opt out.

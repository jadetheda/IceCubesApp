#!/usr/bin/env bash
set -euo pipefail

# IceCubesApp Gallery Mode & Profile Media Files Exporter
# Modeled after interactive workspace export scripts.

BRANCH=""
DO_PULL=false
DOWNLOADS_DIR="${HOME}/Downloads"
INTERACTIVE=false

while getopts "b:pd:hi" opt; do
    case "$opt" in
        b) BRANCH="$OPTARG" ;;
        p) DO_PULL=true ;;
        d) DOWNLOADS_DIR="$OPTARG" ;;
        i) INTERACTIVE=true ;;
        h) 
            echo "Usage: $0 [-b <branch>] [-p] [-d <destination_dir>] [-i]"
            exit 0
            ;;
        *) exit 1 ;;
    esac
done

REPO_DIR="$(pwd)"

if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "Error: Must be run from the root of a git repository (no .git directory found)." >&2
    exit 1
fi

CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)"

if [ "$INTERACTIVE" = true ]; then
    echo "=============================================="
    echo "   IceCubesApp Gallery Mode Dossier Exporter  "
    echo "=============================================="
    echo "Currently on branch: '${CURRENT_BRANCH}'"
    echo ""
    read -r -p "Switch to a different branch? [leave blank to keep '${CURRENT_BRANCH}']: " INPUT_BRANCH
    if [ -n "$INPUT_BRANCH" ]; then
        BRANCH="$INPUT_BRANCH"
    else
        BRANCH="$CURRENT_BRANCH"
    fi

    read -r -p "Pull latest changes from origin for '$BRANCH'? [y/N]: " PULL_CHOICE
    if [[ "$PULL_CHOICE" =~ ^[Yy]$ ]]; then
        DO_PULL=true
    fi
    echo "----------------------------------------------"
fi

if [ -n "$BRANCH" ] && [ "$BRANCH" != "$CURRENT_BRANCH" ]; then
    echo "==> Switching to branch: $BRANCH..."
    git checkout "$BRANCH"
    CURRENT_BRANCH="$BRANCH"
fi

if [ "$DO_PULL" = true ]; then
    echo "==> Pulling latest changes from origin on '$CURRENT_BRANCH'..."
    git fetch origin
    git pull --rebase origin "$CURRENT_BRANCH"
fi

SAFE_BRANCH_NAME="${CURRENT_BRANCH//\//_}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="icecubes_gallery_mode_dossier_${SAFE_BRANCH_NAME}_${TIMESTAMP}.zip"
ZIP_PATH="${DOWNLOADS_DIR}/${ZIP_NAME}"

mkdir -p "$DOWNLOADS_DIR"
STAGE_DIR=$(mktemp -d /tmp/icecubes_gallery_stage_XXXXXX)
trap 'rm -rf "$STAGE_DIR"' EXIT

echo "==> Staging files from branch '${CURRENT_BRANCH}' (${REPO_DIR})..."

# Generate commits.txt
echo "==> Writing commits.txt..."
{
    echo "=== Branch: $CURRENT_BRANCH ==="
    echo "=== HEAD Commit: $(git rev-parse HEAD) ==="
    echo "=== Recent Commits Touching Gallery and Profile Media ==="
    git log -n 35 --pretty=format:"%h %ad | %s%d [%an]" --date=short -- Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift Packages/Account/
    echo -e "\n\n=== Recent Repository Commits (Last 20) ==="
    git log -n 20 --pretty=format:"%h %ad | %s%d [%an]" --date=short
} > "$STAGE_DIR/commits.txt"

copy_rel() {
    local rel_path="$1"
    if [ -e "$REPO_DIR/$rel_path" ]; then
        mkdir -p "$STAGE_DIR/$(dirname "$rel_path")"
        cp -a "$REPO_DIR/$rel_path" "$STAGE_DIR/$rel_path"
        echo "  [+] $rel_path"
    else
        echo "  [-] NOT FOUND: $rel_path" >&2
    fi
}

echo "==> Writing BUG_REPORT_GALLERY_GAPS.md..."
cat << 'EOF' > "$STAGE_DIR/BUG_REPORT_GALLERY_GAPS.md"
# Gallery Mode Thumbnail Loading & Layout Dossier (Post-Overhaul)

> **CRITICAL DISCLAIMER FOR ARGON:**
> The root cause theories, media pipeline explanations, and architectural guesses in this document are **unverified hypotheses** from the assistant agent that has failed to solve these nuances in the past. The user explicitly cautions you **NOT to trust these guesses as settled fact**. Treat them strictly as background context and observations, look at the code with fresh eyes, and form your own independent diagnosis.

---

## 1. Current Verified Symptoms & Problem Statement
Following your architectural overhaul in commit `5b1fbfb8` (which introduced `GalleryMasonryLayout`, bounded aspect ratios `[0.5, 2.0]`, and post deduplication), layout gaps and column voids are significantly improved!

However, the user reports a severe new/persisting issue:
> **"the thumbnails wont load, or if they do they take forever in gallery mode (at least within the same media tab popup context)."**

Observed symptoms:
1. **Thumbnails Fail or Take Forever to Load**: In Gallery Mode—especially when opening the fullscreen media grid from an account's profile Media tab (`AccountDetailView` -> `MediaTab` -> "Fullscreen media" button (`square.grid.2x2`) -> `AccountDetailMediaGridView`)—thumbnails either fail to load completely (staying on progress spinners / secondary background) or load extremely slowly.
2. **Context-Specific Behavior**: In the "same media tab popup context" (`AccountDetailMediaGridView` pushed via `routerPath.navigate(to: .accountMediaGridView(account: account, initialMediaStatuses: fetcher.statusesMedias))`), media loading latency is particularly pronounced.
3. **Bandwidth / Decoding Contention**: When multiple cells appear, they seem to stall each other out or take an excessively long time before rendering.

---

## 2. Core Source Files Included in this Dossier

### Grid Layout & Thumbnail Cell Implementation
- `Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift`: Contains `GalleryMasonryLayout` (custom SwiftUI Layout protocol struct), `GalleryMediaCell` (thumbnail cell view using `LazyResizableImage` and `MediaUIAttachmentVideoView`), aspect ratio modifiers, and context menus.

### Profile Media Views & Navigation
- `Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift`: The fullscreen profile media view (`AccountDetailMediaGridView`) with `AccountMediaFetcher`.
- `Packages/Account/Sources/Account/Detail/Tabs/MediaTab.swift`: Profile Media tab definition (`MediaTabView`), hosting the "Fullscreen media" button and `AnyStatusesListView`.
- `Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift`: Base list view hosting `unboxedGallery` inside account profile tabs.
- `Packages/Account/Sources/Account/Detail/Tabs/StatusesTab.swift`: Pinned posts gallery integration in user profiles.
- `Packages/Account/Sources/Account/Detail/AccountDetailView.swift`: Parent profile view.
- `IceCubesApp/App/Router/AppRegistry.swift` & `Packages/Env/Sources/Env/Router.swift`: Navigation routing for `.accountMediaGridView`.

### Image Loading & Video Playback
- `Packages/DesignSystem/Sources/DesignSystem/Views/LazyResizableImage.swift`: NukeUI `LazyImage` wrapper with `GeometryReader` and `.resize` image processor.
- `Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift`: Video player component used for video/gifv attachments.

### Media Models & Metadata
- `Packages/Models/Sources/Models/MediaAttachement.swift`: Attachment model, `displayInfo` URL resolution, `previewUrl`, `remoteUrl`, `aspectRatio`, and `galleryAspectRatio`.
- `Packages/Models/Sources/Models/MediaStatus.swift`: Wrapper connecting `Status` and `MediaAttachment`.
- `Packages/Models/Sources/Models/Status.swift`: Status model with `asMediaStatus` visual media filtering.
- `Packages/Models/Sources/Models/Timeline/TimelineItem.swift`: Timeline model.

### Timeline & Preferences
- `Packages/Timeline/Sources/Timeline/View/TimelineListView.swift`: Timeline view hosting `GalleryStatusesListView`.
- `Packages/Timeline/Sources/Timeline/TimelineContentFilter.swift`: Handles `isGalleryMode` filter state.
- `Packages/Env/Sources/Env/UserPreferences.swift`: Preferences controlling columns, square crop, remote media fallback, and delays.

---

## 3. Recent Commit History
- **`5b1fbfb8`**: Integrated Argon's initial overhaul:
  * Replaced `HStack { LazyVStack }` with `GalleryMasonryLayout: Layout`.
  * Added `AccountMediaFetcher.deduplicateStatuses` to eliminate $N \times N$ status duplication.
  * Bounded aspect ratios in `[0.5, 2.0]` via `MediaAttachment.galleryAspectRatio(isSquare:)`.
  * Filtered `.audio` attachments from `Status.asMediaStatus`.
  * Removed unary modifiers on `unboxedGallery` in `AnyStatusesListView`.
- **`95973adc`**: Resolved Swift 6 `.defaultIsolation(MainActor.self)` on `GalleryLayoutItemKindKey` / `GalleryMasonryLayout` by marking them `public nonisolated`, and added optional chaining to `statusOnMediaLoaded?()`. (CI Build #42363077422 passed in 10m22s).

---

## 4. Agent's Unverified Hypotheses (READ WITH SKEPTICISM!)
*Reminder: These are solely speculative guesses from the assistant agent. Do NOT treat them as verified facts!*

### Hypothesis A: Full-Resolution Image URLs vs Thumbnail Preview URLs
In `GalleryStatusesListView.swift` (`GalleryMediaCell`):
```swift
private var info: MediaAttachment.DisplayInfo? {
  mediaStatus.attachment.displayInfo(
    useRemoteMedia: effectiveUseRemoteMedia,
    fallbackOnFail: fallback,
    neverLoadVideo: false
  )
}
private var resolvedUrl: URL? { info?.url }
private var resolvedLazyImageUrl: URL? { ... return resolvedUrl }
```
In `MediaAttachment.displayInfo`:
- `info.url` is the **original full-size master image URL** (which can be a 10MB–20MB 4K/8K uncompressed file).
- `info.previewUrl` (or `attachment.previewUrl`) is the **server-scaled small thumbnail URL** (typically a fast ~30KB–50KB WebP/JPEG generated by the Fediverse instance).
- If `GalleryMediaCell` is loading `info.url` instead of `info.previewUrl`, loading 20+ full-resolution photos simultaneously will saturate network bandwidth and memory, causing thumbnails to take forever or fail.

### Hypothesis B: Video Cells Instantiating Full AVPlayers
In `GalleryMediaCell`:
`neverLoadVideo: false` is passed to `displayInfo`. When a post has `.video` or `.gifv`:
```swift
case .gifv, .video:
  MediaUIAttachmentVideoView(...)
```
This mounts an `AVPlayer` streaming the full video file in every video cell in the grid simultaneously, rather than showing a static video preview thumbnail (`previewUrl`).

### Hypothesis C: Remote Server Bypassing & Auto-Fallback Timer Thrashing
In `AccountDetailMediaGridView`:
```swift
private var isRemote: Bool {
  guard let host = account.url?.host else { return false }
  return host.lowercased() != client.server.lowercased()
}
```
If viewing a remote user's profile, `isRemote` is `true`. This causes `effectiveUseRemoteMedia` to be `true`, bypassing the local instance's cached proxy and attempting direct HTTPS connections to third-party Fediverse servers (which may be slow, rate-limited, or blocked).
Furthermore, `autoFallbackTriggered` runs a 3-second sleep task: if an image hasn't loaded in 3 seconds, it flips `autoFallbackTriggered = true`, triggering a view re-render and restarting the image request from scratch.

### Hypothesis D: LazyResizableImage Initial Size (0, 0) Processor Bypass
In `LazyResizableImage.swift`:
```swift
.processors(sizeToUse.width > 0 && sizeToUse.height > 0 ? [.resize(size: sizeToUse)] : [])
```
On initial layout within a custom `Layout` or `ScrollView`, `proxy.size` may evaluate to `(0, 0)`. When width/height are 0, Nuke's resize processor is skipped (`[]`), causing Nuke to decode full unscaled bitmaps into memory.

### Hypothesis E: Client Nil in AccountDetailMediaGridView Initialization
In `AccountDetailMediaGridView.swift`:
```swift
public init(account: Account, initialMediaStatuses: [MediaStatus]) {
  self.account = account
  let rawStatuses = initialMediaStatuses.map { $0.status }
  let uniqueStatuses = AccountMediaFetcher.deduplicateStatuses(rawStatuses)
  _fetcher = .init(initialValue: AccountMediaFetcher(accountId: account.id, initialStatuses: uniqueStatuses))
}
```
`AccountMediaFetcher` is initialized without a `client` (since `client` is an `@Environment` property only available in `body`). In `AccountMediaFetcher.init`, `StatusDataControllerProvider.shared.updateDataControllers(for: uniqueStatuses, client: client)` cannot run because `client` is nil, and `fetcher.client = client` is only attached in `.onAppear`.

---

## 5. Potential Directions for Argon to Explore
- Check whether `GalleryMediaCell` should request thumbnail/preview URLs (`previewUrl` / `previewRemoteUrl`) instead of full `url`.
- Check whether video/gifv attachments in gallery grid cells should display static preview image thumbnails (`previewUrl`) with a play icon badge rather than spawning active `MediaUIAttachmentVideoView` / `AVPlayer` instances.
- Inspect `LazyResizableImage` and `NukeUI` caching/pipeline configuration.
- Check `AccountDetailMediaGridView` client attachment and initial status population.
EOF

echo "==> Copying documentation and agent context..."
copy_rel "AGENTS.md"
copy_rel "memory.md"
copy_rel "notes_and_lessons.md"
copy_rel "style-guidelines-for-docs.md"
copy_rel "attributions.md"

echo "==> Copying StatusKit gallery files..."
copy_rel "Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift"
copy_rel "Packages/StatusKit/Sources/StatusKit/List/StatusesListView.swift"
copy_rel "Packages/StatusKit/Sources/StatusKit/List/StatusVisibilityModifier.swift"
copy_rel "Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift"

echo "==> Copying Account profile and media tabs..."
copy_rel "Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift"
copy_rel "Packages/Account/Sources/Account/Detail/Tabs/MediaTab.swift"
copy_rel "Packages/Account/Sources/Account/Detail/Tabs/StatusesTab.swift"
copy_rel "Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift"
copy_rel "Packages/Account/Sources/Account/Detail/Tabs/Base/AccountTabProtocol.swift"
copy_rel "Packages/Account/Sources/Account/Detail/AccountDetailView.swift"
copy_rel "Packages/Account/Sources/Account/StatusesLists/AccountStatusesListView.swift"

echo "==> Copying App & Router files..."
copy_rel "IceCubesApp/App/Router/AppRegistry.swift"
copy_rel "Packages/Env/Sources/Env/Router.swift"

echo "==> Copying Timeline gallery integration..."
copy_rel "Packages/Timeline/Sources/Timeline/View/TimelineListView.swift"
copy_rel "Packages/Timeline/Sources/Timeline/TimelineContentFilter.swift"

echo "==> Copying Preferences..."
copy_rel "Packages/Env/Sources/Env/UserPreferences.swift"

echo "==> Copying MediaUI & DesignSystem image loaders..."
copy_rel "Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift"
copy_rel "Packages/DesignSystem/Sources/DesignSystem/Views/LazyResizableImage.swift"

echo "==> Copying Models..."
copy_rel "Packages/Models/Sources/Models/MediaAttachement.swift"
copy_rel "Packages/Models/Sources/Models/MediaStatus.swift"
copy_rel "Packages/Models/Sources/Models/Status.swift"
copy_rel "Packages/Models/Sources/Models/Timeline/TimelineItem.swift"

echo "==> Creating ZIP archive at ${ZIP_PATH}..."
python3 -c "
import os, zipfile
stage = '$STAGE_DIR'
zip_out = '$ZIP_PATH'
with zipfile.ZipFile(zip_out, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(stage):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, stage)
            z.write(full, rel)
"

# Also maintain a stable symlink/copy for easy attachment
cp -f "$ZIP_PATH" "${DOWNLOADS_DIR}/icecubes_gallery_mode_dossier.zip"

echo "==> Success! Exported archive: ${ZIP_PATH} ($(du -h "$ZIP_PATH" | cut -f1))"
echo "==> Updated stable shortcut: ${DOWNLOADS_DIR}/icecubes_gallery_mode_dossier.zip"

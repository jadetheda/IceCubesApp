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
# Gallery Mode Gaps & Layout Desynchronization Bug Dossier

> **CRITICAL DISCLAIMER FOR ARGON:**
> The root cause theories, layout explanations, and architectural guesses in this document are **unverified hypotheses** from previous AI agents that repeatedly tried and **FAILED** to permanently fix this bug. The user explicitly cautions you **NOT to trust these guesses as settled fact**. Treat them strictly as observations of what previous attempts explored, look at the code with fresh eyes, and form your own independent diagnosis.

---

## 1. Verified Symptoms & Problem Statement
In IceCubesApp (SwiftUI, targeting iOS 17 & 18), **Gallery Mode** provides a multi-column masonry grid layout for media-rich statuses. While it is somewhat usable in the general timeline, a severe **gaps and layout desynchronization bug** stubbornly persists—most visibly in the **Profile Media Tab grid** (`AccountDetailView` -> `MediaTab` -> `AnyStatusesListView` / `AccountDetailMediaGridView`).

Observed symptoms:
1. **Vertical Voids & Disconnected Cards**: Large, irregular vertical empty spaces (gaps) appear between items or underneath columns in the grid.
2. **Column Height Imbalance**: One column will suddenly cut off or have a huge void of dead whitespace before the next row or batch of images appears.
3. **Layout Jumping on Image Load**: Posts with media that do not have pre-fetched aspect ratio metadata from the server jump in size and disrupt spacing once the image downloads.
4. **List vs ScrollView Inconsistencies**: The bug appears differently depending on where Gallery Mode is rendered (e.g. standalone in a `ScrollView` vs embedded inside an account profile's parent `List`).

---

## 2. Core Source Files Included in this Dossier

### Grid Layout Implementation
- `Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift`: The primary gallery grid view (`GalleryStatusesListView`), chunking logic (`chunkItems`), column balancing math (`computeColumnItems`), and thumbnail cell (`GalleryMediaCell`).

### Profile Media Views & Tabs
- `Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift`: Fullscreen profile media gallery view.
- `Packages/Account/Sources/Account/Detail/Tabs/MediaTab.swift`: Profile Media tab definition and fetcher.
- `Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift`: Base list view hosting `unboxedGallery` inside account profile tabs.
- `Packages/Account/Sources/Account/Detail/Tabs/StatusesTab.swift`: Contains an independent inline duplicate of the gallery grid for pinned posts (lines 188–245).
- `Packages/Account/Sources/Account/Detail/AccountDetailView.swift`: The parent view hosting all profile tabs inside a root SwiftUI `List`.

### Timeline & Preferences
- `Packages/Timeline/Sources/Timeline/View/TimelineListView.swift`: Timeline view hosting `GalleryStatusesListView` inside a `ScrollView`.
- `Packages/Timeline/Sources/Timeline/TimelineContentFilter.swift`: Handles `isGalleryMode` filter state.
- `Packages/Env/Sources/Env/UserPreferences.swift`: Preferences controlling columns (`galleryColumns`), square cropping (`galleryCropToSquare`), margins, and layout optimization (`galleryOptimizeItemLayout`).

### Media & Model Helpers
- `Packages/MediaUI/Sources/MediaUI/LazyResizableImage.swift` & `MediaUIAttachmentVideoView.swift`: Media loaders used by `GalleryMediaCell`.
- `Packages/Models/Sources/Models/MediaAttachment.swift`, `Status.swift`, `TimelineItem.swift`: Data models and attachment aspect ratio properties.

---

## 3. History of Past Failed Attempts (From Git Log)
Here is what past agents attempted, what happened, and why the bug was not solved:

1. **Commit `f71b6d31` ("fix: Resolve massive vertical gaps in gallery mode by aligning LazyVStack to top")**:
   - *What was tried*: Added `.frame(maxHeight: .infinity, alignment: .top)` to the inner `LazyVStack` columns inside `GalleryStatusesListView.swift`.
   - *Agent's hypothesis at the time*: Thought `LazyVStack` was vertically centering its items when the parent `HStack` expanded to the tallest column.
   - *Outcome*: Gaps still persist, especially between chunk boundaries and in profile media grids.

2. **Commits `bbb5f76d` & `75abd5f9` ("fix: Fully rip out gallery chunking to restore single continuous masonry grid" -> REVERTED)**:
   - *What was tried*: Ripped out `GalleryChunk`, `chunkItems`, and `makeGridChunk` to make one single continuous `HStack` masonry grid.
   - *Outcome*: Quickly reverted (`75abd5f9`) because `TimelineGap` items (loading markers in timelines) had no clean way to render full-width across multi-column layouts without chunking, or caused other regressions.

3. **Commit `64deb6af` ("fix: Restore dynamic sizing for gallery media without aspect ratio metadata")**:
   - *What was tried*: Changed `GalleryMediaCell` to use `LazyImage` with `.scaledToFit()` when `aspectRatio == nil && !isSquare`, and made `GalleryAspectRatioModifier` return raw `content` instead of defaulting to a 1:1 aspect container.
   - *Outcome*: Items without aspect ratios now display, but cause unexpected column height recalculations when the image actually finishes loading.

4. **Commit `af35366f` ("fix: prevent list row from capturing context menu bounding box in profile gallery")**:
   - *What was tried*: Added `.buttonStyle(.borderless)` to thumbnail buttons and `.listRowBackground(Color.clear)` to `AnyStatusesListView`.
   - *Outcome*: Fixed context menu highlighting, but the underlying layout gaps remained.

---

## 4. Agent's Unverified Hypotheses (READ WITH SKEPTICISM!)
*Reminder: These are only guesses from the previous agent. Do not assume they are correct.*

- **Hypothesis A (List Container Mismatch)**: The main timeline renders `GalleryStatusesListView` inside a `ScrollView { LazyVStack { ... } }`. But on user profiles, `AccountDetailView` hosts tabs inside a parent SwiftUI `List`. `AnyStatusesListView` renders `unboxedGallery` as a single `List` row. Embedding a multi-column `HStack` with nested `LazyVStack`s inside a `List` cell may be confusing `UICollectionView`'s height estimator.
- **Hypothesis B (Chunk-Boundary Holes)**: `chunkItems` splits the timeline items whenever a gap or section break occurs. If Chunk 1's left column ends at height 900pt and its right column ends at height 500pt, Chunk 2 starts below the 900pt mark, leaving a 400pt void under the right column.
- **Hypothesis C (Aspect Ratio Balancing vs Render Reality)**: `computeColumnItems` estimates heights using `1.0 / (aspectRatio ?? 1.0)`. If metadata lacks aspect ratios, it guesses 1.0. When an image turns out to be a tall 9:16 portrait, the actual rendered height diverges from what the greedy column-packing algorithm calculated.
- **Hypothesis D (StatusesTab Duplicate Code)**: `StatusesTab.swift` (lines 188–245) has a completely separate, duplicate copy of the masonry layout for pinned posts that did not receive the fixes applied to `GalleryStatusesListView.swift`.

---

## 5. Potential Directions to Explore
Argon, feel free to discard any or all of the above guesses. Some potential clean-slate directions you might consider:
- Investigating whether an iOS 16+ custom `Layout` protocol (e.g. `MasonryLayout: Layout`) would avoid `HStack` + `LazyVStack` sizing traps entirely.
- Checking how `AccountDetailView` can host the profile Media tab in a native `ScrollView` instead of jamming it into a `List` row.
- Checking if fixed/clamped placeholder aspect ratios prevent jumping when remote images load.
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

echo "==> Success! Exported archive: ${ZIP_PATH} ($(du -h "$ZIP_PATH" | cut -f1))"

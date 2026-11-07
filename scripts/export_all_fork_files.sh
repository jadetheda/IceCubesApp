#!/usr/bin/env bash
set -euo pipefail

# IceCubesApp All Fork Modified Files Exporter
# Packages all source code, models, packages, configurations, and documentation
# modified or created since branching from upstream.

DOWNLOADS_DIR="${HOME}/Downloads"
BRANCH=""

while getopts "b:d:h" opt; do
    case "$opt" in
        b) BRANCH="$OPTARG" ;;
        d) DOWNLOADS_DIR="$OPTARG" ;;
        h) 
            echo "Usage: $0 [-b <branch>] [-d <destination_dir>]"
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
if [ -n "$BRANCH" ] && [ "$BRANCH" != "$CURRENT_BRANCH" ]; then
    echo "==> Switching to branch: $BRANCH..."
    git checkout "$BRANCH"
    CURRENT_BRANCH="$BRANCH"
fi

SAFE_BRANCH_NAME="${CURRENT_BRANCH//\//_}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="icecubes_all_fork_modified_files_${SAFE_BRANCH_NAME}_${TIMESTAMP}.zip"
ZIP_PATH="${DOWNLOADS_DIR}/${ZIP_NAME}"
STABLE_ZIP_PATH="${DOWNLOADS_DIR}/icecubes_all_fork_modified_files.zip"

mkdir -p "$DOWNLOADS_DIR"
STAGE_DIR=$(mktemp -d /tmp/icecubes_fork_stage_XXXXXX)
trap 'rm -rf "$STAGE_DIR"' EXIT

UPSTREAM_REF="upstream/main"
if ! git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1; then
    echo "Warning: $UPSTREAM_REF not found locally. Fetching upstream..."
    git fetch upstream main || true
fi

MERGE_BASE="$(git merge-base "$CURRENT_BRANCH" "$UPSTREAM_REF" 2>/dev/null || echo "upstream/main")"

echo "=============================================="
echo "   IceCubesApp Fork Modified Files Exporter   "
echo "=============================================="
echo "Branch: $CURRENT_BRANCH"
echo "Upstream Ref: $UPSTREAM_REF"
echo "Merge Base: $MERGE_BASE"
echo "Destination: $ZIP_PATH"
echo "----------------------------------------------"

# Generate commits_since_upstream.txt
echo "==> Generating commits_since_upstream.txt..."
{
    echo "=== IceCubesApp Fork Commit History ==="
    echo "=== Branch: $CURRENT_BRANCH ==="
    echo "=== HEAD Commit: $(git rev-parse HEAD) ==="
    echo "=== Upstream Base: $MERGE_BASE ==="
    echo ""
    echo "=== Commits on Fork since Upstream ==="
    git log --pretty=format:"%h %ad | %s%d [%an]" --date=short "${MERGE_BASE}..HEAD"
} > "$STAGE_DIR/commits_since_upstream.txt"

# Generate FORK_CHANGES_MANIFEST.md
echo "==> Writing FORK_CHANGES_MANIFEST.md..."
cat << EOF > "$STAGE_DIR/FORK_CHANGES_MANIFEST.md"
# IceCubesApp Fork Changes Manifest

This archive contains all repository files modified, added, or maintained in the **jadetheda/IceCubesApp** fork since branching from upstream (**Dimillian/IceCubesApp**).

- **Fork Branch**: \`${CURRENT_BRANCH}\` (Commit: \`$(git rev-parse --short HEAD)\`)
- **Upstream Base**: \`${MERGE_BASE}\` (v2.1.7 sync point)
- **Export Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

---

## 1. Major Functional Features & Architectural Changes in this Fork

1. **Continuous 2D Waterfall Gallery Mode Overhaul**:
   - Replaced legacy multi-column \`HStack { LazyVStack }\` layout with continuous \`GalleryMasonryLayout\` (custom SwiftUI \`Layout\` protocol struct).
   - Coordinates computed from exact pixel dimensions with real 4pt spacing, eliminating cumulative column height drift and vertical whitespace voids.
   - Bounded aspect ratios in \`[0.5, 2.0]\` to guarantee placeholder, progress spinner, and downloaded media share identical bounding boxes.
   - Added status deduplication (\`AccountMediaFetcher.deduplicateStatuses\`) to prevent multi-attachment posts from multiplying into \$N \times N\$ cell copies.
   - Non-visual media filtering (\`.audio\`) prevents phantom height allocations.

2. **Hide Seen Posts & Timeline Content Filtering**:
   - Complete tracking and suppression of read/seen posts from home and custom timelines.
   - Dynamic 5-second media load timers and scroll visibility modifiers (\`StatusVisibilityModifier\`, \`SeenPostsManager\`).
   - Content filter enhancements: 4-way media filters, language-based text post hiding (including on-device \`NaturalLanguage\` detection), sensitive content suppression, and bot post filtering.

3. **Inline Translation & Language Detection**:
   - Twitter/X-style minimal inline translation header (\`[icon] Translated from <Lang>  Show original\`).
   - On-device Apple Translation integration via iOS 18+ \`TranslationSession\` with fallback for servers lacking DeepL/LibreTranslate backends.
   - Interactive markdown hyperlink preservation and URL un-shortening in translated text.
   - Dynamic RTL/LTR text directionality for Arabic, Hebrew, Urdu, and Persian.
   - Bounded in-memory translation cache (500 items, FIFO eviction).

4. **Remote Media Auto-Fallback & Direct Loading**:
   - Support for Mastodon \`remote_url\` fallback when local instance caching fails or takes too long.
   - Configurable auto-fallback delay in Content Settings with background timeout interception.

5. **Settings & Customization Modernization**:
   - Sentence case standardization across all Settings surfaces.
   - Full human localization across 19 languages in \`Localizable.xcstrings\`.
   - Segmented Favorite vs. Like picker with native SF Symbols (Star vs. Heart) and rapid-switching re-entrancy hardening.

6. **Automated CI/CD Build & Packaging**:
   - Fully automated unsigned IPA building, packaging, and artifact uploading via GitHub Actions (\`build-ipa.yml\`).
   - AltStore JSON repository generation (\`generate_altstore.py\` & \`altstore.yml\`).
   - Swift 5.10 / Swift 6 ViewBuilder AST constraint solver optimization and strict concurrency hardening.

---

## 2. Package-by-Package File Breakdown
See \`commits_since_upstream.txt\` for the chronological commit history.
EOF

# Copy all modified files excluding large debug logs and temporary backups
echo "==> Staging modified files..."
python3 -c "
import subprocess, os, shutil

repo = '$REPO_DIR'
stage = '$STAGE_DIR'
upstream_base = '$MERGE_BASE'

files = subprocess.check_output(
    ['git', 'diff', '--name-only', '--diff-filter=d', upstream_base, 'HEAD'],
    cwd=repo
).decode().splitlines()

ignored_patterns = [
    'png_backup.json.gz',
    'extracted_logs',
    'failed_logs.txt',
    'full_logs',
    'full_log',
    'step_log',
    'logs.zip',
    'run_log',
    'live_log',
    'gallery_top.txt',
    '.orig',
    '.rej',
    '.bak',
    '='
]

count = 0
for rel in files:
    if any(p in rel for p in ignored_patterns):
        continue
    src = os.path.join(repo, rel)
    if os.path.exists(src):
        dst = os.path.join(stage, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        count += 1

print(f'Successfully staged {count} modified fork files.')
"

echo "==> Compressing archive to ${ZIP_PATH}..."
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

# Create stable shortcut
cp -f "$ZIP_PATH" "$STABLE_ZIP_PATH"

echo "==> Success! Exported archive:"
echo "    Timestamped: ${ZIP_PATH} ($(du -h "$ZIP_PATH" | cut -f1))"
echo "    Stable link: ${STABLE_ZIP_PATH} ($(du -h "$STABLE_ZIP_PATH" | cut -f1))"

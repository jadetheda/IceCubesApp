#!/usr/bin/env bash
set -euo pipefail

# IceCubesApp All Source Code Exporter
# Packages 100% of the project's source code, packages, configs, schemes,
# documentation, and bug dossiers into a clean, lightweight archive for AI analysis.

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
ZIP_NAME="icecubes_all_source_code_${SAFE_BRANCH_NAME}_${TIMESTAMP}.zip"
ZIP_PATH="${DOWNLOADS_DIR}/${ZIP_NAME}"
STABLE_ZIP_PATH="${DOWNLOADS_DIR}/icecubes_all_source_code.zip"

mkdir -p "$DOWNLOADS_DIR"
STAGE_DIR=$(mktemp -d /tmp/icecubes_all_source_stage_XXXXXX)
trap 'rm -rf "$STAGE_DIR"' EXIT

UPSTREAM_REF="upstream/main"
if ! git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1; then
    git fetch upstream main 2>/dev/null || true
fi
MERGE_BASE="$(git merge-base "$CURRENT_BRANCH" "$UPSTREAM_REF" 2>/dev/null || echo "upstream/main")"

echo "=============================================="
echo "    IceCubesApp Complete Source Code Packager "
echo "=============================================="
echo "Branch: $CURRENT_BRANCH"
echo "Commit: $(git rev-parse --short HEAD)"
echo "Destination: $ZIP_PATH"
echo "----------------------------------------------"

# 1. Generate commit log since upstream
echo "==> Generating commits_since_upstream.txt..."
{
    echo "=== IceCubesApp Fork Commit History ==="
    echo "=== Branch: $CURRENT_BRANCH ==="
    echo "=== HEAD Commit: $(git rev-parse HEAD) ==="
    echo "=== Upstream Base: $MERGE_BASE ==="
    echo ""
    echo "=== Commits on Fork since Upstream ==="
    git log --pretty=format:"%h %ad | %s%d [%an]" --date=short "${MERGE_BASE}..HEAD" 2>/dev/null || git log -n 500 --pretty=format:"%h %ad | %s%d [%an]" --date=short
} > "$STAGE_DIR/commits_since_upstream.txt"

# 2. Copy dossiers if available
if [ -f "${DOWNLOADS_DIR}/FORK_CHANGES_MANIFEST.md" ]; then
    cp -f "${DOWNLOADS_DIR}/FORK_CHANGES_MANIFEST.md" "$STAGE_DIR/FORK_CHANGES_MANIFEST.md"
fi
if [ -f "${DOWNLOADS_DIR}/GALLERY_THUMBNAILS_BUG_DOSSIER.md" ]; then
    cp -f "${DOWNLOADS_DIR}/GALLERY_THUMBNAILS_BUG_DOSSIER.md" "$STAGE_DIR/GALLERY_THUMBNAILS_BUG_DOSSIER.md"
fi

# 3. Stage all source code files
echo "==> Staging all project source code, configurations, and documentation..."
python3 -c "
import subprocess, os, shutil

repo = '$REPO_DIR'
stage = '$STAGE_DIR'

files = subprocess.check_output(['git', 'ls-files'], cwd=repo).decode().splitlines()

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
    'screenshots.pco',
    'AppIcon.icon',
    'venv/'
]

binary_exts = ('.png', '.wav', '.caf', '.ttf', '.otf', '.pco', '.icon', '.ico', '.gz', '.zip')

count = 0
for rel in files:
    if any(p in rel for p in ignored_patterns):
        continue
    if rel.lower().endswith(binary_exts):
        continue
    src = os.path.join(repo, rel)
    if os.path.exists(src) and not os.path.isdir(src):
        dst = os.path.join(stage, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        count += 1

print(f'Successfully staged {count} source code files.')
"

# 4. Also copy active helper scripts in scripts/ if not tracked
if [ -d "${REPO_DIR}/scripts" ]; then
    for s in "${REPO_DIR}/scripts"/*; do
        if [ -f "$s" ]; then
            rel="scripts/$(basename "$s")"
            if [ ! -f "$STAGE_DIR/$rel" ]; then
                cp -f "$s" "$STAGE_DIR/$rel"
            fi
        fi
    done
fi

# 5. Compress
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

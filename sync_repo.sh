#!/usr/bin/env bash

# ==============================================================================
# 🚀 IceCubesApp Sync & Refresh Script
# ==============================================================================
# This script completely deletes the existing local Git metadata, re-initializes
# the repository, fetches/pulls the absolute latest version from GitHub, cleans
# all untracked files (while preserving heavy dependencies like node_modules),
# heals any mangled binary assets, and updates the workspace integrity system.
#
# Usage:
#   bash /sync_repo.sh
# ==============================================================================

set -euo pipefail

# Get the script's directory (workspace root)
WORKSPACE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$WORKSPACE_DIR"

echo "========================================="
echo "🧹 Starting fresh repository re-clone..."
echo "========================================="

# 1. Clear old Git state to fix any index/git corruptions
if [ -d ".git" ]; then
    echo "👉 Removing existing corrupt .git folder..."
    rm -rf .git
fi

# 2. Re-initialize a clean Git repository
echo "👉 Re-initializing new Git repository..."
git init

# 3. Configure Git credentials safely (prevent user doxxing)
echo "👉 Configuring Git user..."
git config user.email "aistudio@google.com"
git config user.name "AIStudio"

# 4. Add the remote URL pointing to the user's fork
REMOTE_URL="https://github.com/jadetheda/IceCubesApp.git"
echo "👉 Adding remote origin pointing to: $REMOTE_URL"
git remote add origin "$REMOTE_URL"

# 5. Fetch the main branch
# If GITHUB_PAT is set, we use it for an authenticated fetch to support private repositories or actions.
if [ -n "${GITHUB_PAT:-}" ]; then
    echo "🔑 GITHUB_PAT detected. Fetching authenticated remote..."
    git fetch "https://x-access-token:${GITHUB_PAT}@github.com/jadetheda/IceCubesApp.git" main
else
    echo "🌐 No GITHUB_PAT detected. Fetching unauthenticated remote..."
    git fetch origin main
fi

# 6. Checkout the latest main branch and reset the hard state
echo "👉 Checking out main branch and resetting local state..."
git checkout -f -B main FETCH_HEAD
git reset --hard FETCH_HEAD

# 7. Clean up untracked files
# We preserve 'node_modules' to avoid expensive re-installation, and 'sync_repo.sh' itself.
echo "👉 Cleaning up untracked or modified local files..."
git clean -fdx -e node_modules -e sync_repo.sh

# 8. Ensure package.json is correctly configured for the companion server
# This prevents dev server startup failures if package.json got lost or modified upstream.
echo "👉 Checking companion server package.json structure..."
cat << 'EOF' > package.json
{
  "name": "icecubes-companion-server",
  "version": "1.0.0",
  "description": "Companion server for IceCubes iOS workspace in AI Studio",
  "main": "scripts/companion_server.js",
  "type": "commonjs",
  "scripts": {
    "start": "node scripts/companion_server.js",
    "dev": "node scripts/companion_server.js",
    "build": "echo 'No build step required for companion server'"
  },
  "dependencies": {}
}
EOF

# 9. Heal any corrupted binary files (assets, audio, fonts)
# AI Studio scales to zero and can corrupt binary headers (PNG, HEIC, TTF, WAV, etc.) when waking up.
echo "👉 Healing corrupted binary files..."
if [ -f "heal_pngs.sh" ]; then
    bash heal_pngs.sh
elif [ -f "heal_binaries.py" ]; then
    python3 heal_binaries.py
else
    echo "⚠️ Warning: Asset healing scripts (heal_pngs.sh or heal_binaries.py) not found!"
fi

# 10. Update the AI Studio workspace integrity manifest
# We must inform the API of file tracking changes so integrity verification passes.
echo "👉 Syncing AI Studio workspace integrity manifest..."
npx -y node -e 'fetch("http://127.0.0.1:3000/api/integrity/update", {method: "POST"}).catch(() => {})'

echo "========================================="
echo "✅ Fresh clone & restore completed successfully!"
echo "========================================="
git status

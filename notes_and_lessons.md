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

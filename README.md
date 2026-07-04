# iOS Development Workspace

This project provides an isolated environment for developing native iOS applications (like the Ice Cubes Mastodon client) directly from an iPhone using AI Studio and GitHub Actions.

## The Architecture
Because AI Studio runs in a Linux container, it cannot natively compile iOS `.ipa` files. Furthermore, the default AI Studio "Export to GitHub" platform feature can be destructive to complex Xcode projects by ignoring `.gitignore` rules and pushing binaries.

To circumvent this, we use a **Direct Server-Side Push** pipeline:
1. **Develop:** The AI edits the Xcode project strictly within the `/ios-workspace` folder (which is already a cloned Git repository on the server).
2. **Push:** You click the "Push Directly to GitHub" button in the built-in web dashboard. This pushes the changes instantly from the AI Studio server using 0 MB of your mobile data.
3. **Compile (GitHub Actions):** A workflow in your repo triggers a macOS runner to build an **unsigned** `.ipa`.
4. **Sideload:** You download the unsigned artifact from GitHub and install it using SideStore or AltStore.

## Workflow Loop
1. Request code changes via the AI Studio chat interface.
2. Verify the workspace integrity on the web dashboard.
3. Click **Push Directly to GitHub**.
4. Wait 10-15 minutes for GitHub Actions to produce the unsigned `.ipa` artifact.
5. Download the artifact and sideload it via SideStore or AltStore.

*Note: The legacy `a-shell mini` ZIP download method is still available in the dashboard for manual backup purposes, but is no longer required for standard development.*

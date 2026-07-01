## 📝 Activity & Learning Logging Guideline
- You MUST append every single modification, optimization, bug fix, and structural change you perform to `/memory.md` under the "## 🪵 Activity Log" section.
- Keep the log readable, chronological, and technically precise, containing:
  - Timestamp (UTC)
  - Change description (e.g., optimizations, UX tweaks, fixing connection/polling freezes)
  - Impact on the app's offline/production readiness.

## 📚 Documentation & README Guideline
- You MUST maintain the following core documentation files for this project:
  1. `/README.md` (Update after modifying compiling flows, APIs, local scripts, or offline setups)
  2. `/memory.md` (Update every turn with modifications and fixes)
  3. `/notes_and_lessons.md` (Update with experiments, successes, failures, and important notes provided by the user)
  4. `/style-guidelines-for-docs.md` (Contains rules for keeping writing strictly non-AI and non-slop)
  5. `/attributions.md` (Maintain a list of open-source credits and external code sources used in the project. Update this file EVERY time outside code is incorporated or every time the attributions section in the UI is changed.)
- **CRITICAL REQUIREMENT:** All new documentation you write or update MUST strictly follow the rules defined in `/style-guidelines-for-docs.md`. Do not use AI filler vocabulary, do not use "Hype Slop", and embrace asymmetry and brevity.

## 🛡️ Workspace Integrity & Agent File Modification
- **NO ARBITRARY SANDBOX MODIFICATIONS**: We NEVER touch anything in the sandbox/workspace unless we are purposely modifying the IceCubes application itself. Do not edit, create, or restructure files outside of direct requirements for the IceCubes app.
- We have a SHA-256 integrity verification system in place for files within the `ios-workspace` folder to detect false-positive corruptions from AI Studio.
- **CRITICAL RULE**: When you (the agent) legitimately modify, add, or delete files inside `ios-workspace`, you MUST update the integrity manifest by making a POST request to the API: `npx -y node -e 'fetch("http://127.0.0.1:3000/api/integrity/update", {method: "POST"})'` via `shell_exec`, so you don't trip your own corruption alarms.

## ⚠️ AI Studio GitHub Push Mangling Warning
- **DO NOT** rely on AI Studio's default "Export to GitHub" feature without severe caution. 
- **The Issue:** The native AI Studio GitHub push heavily mangles the repository state. It frequently ignores strict `.gitignore` rules, pushing massive binary files (`.bin`, `.chd`, `.iso`, build artifacts) directly to the remote, bloating the repository and causing LFS rejections. Furthermore, it risks overwriting custom dotfiles and agent-specific documentation files (like this very `AGENTS.md` file) with default platform templates.
- **Agent Action:** When discussing version control or repository backups, warn the user about this behavior. Always ensure the `.gitignore` is fully robust and suggest using terminal-based Git pushes or ZIP exports instead of the default AI Studio GitHub integration to preserve structural integrity.

## ⚖️ Attribution & External Code Tracking
- **The Issue:** As projects grow and external snippets/libraries are integrated, the origin of the code gets lost, making licensing and debugging a nightmare.
- **The Fix:** You MUST maintain the `/attributions.md` file. Establish a rigid rule that every time external code, open-source logic, or third-party specifications are incorporated, this file MUST be updated immediately.
- **Action:** Check if `/attributions.md` needs an update every single time you implement external code. It serves as a single source of truth for all dependencies and third-party specs.

## 🐛 Bug Checking & Responsiveness (Exit Code 65 Rule)
- **Check for Bugs**: You MUST always proactively check for bugs and potential edge cases in your code before committing changes. If you implement a new feature (like a toolbar button or modifier), ensure it does not break layout or cause compilation timeouts.
- **Do NOT disappear on Exit Code 65**: If a GitHub Action build fails with Exit Code 65 (or any compiler crash/timeout) during your background tasks, you must fix it, but NEVER continuously loop trying to fix it without getting back to the user. If you encounter a complex Exit Code 65, inform the user of the failure and your plan instead of silently retrying forever in the background.
- **Learn from Exit Code 65**: Every time you encounter and fix an Exit Code 65 (or any compiler crash), you MUST document the root cause and the solution here in AGENTS.md so that you learn from it and prevent the same mistake from causing timeouts in the future.

## ⚠️ AI Studio Agent Shell (shell_exec) Limitations & Workarounds
1. **Strict Command Whitelist (The "Mini Shell" Constraint)**: The agent's shell execution tool is highly locked down. It does NOT have access to a standard bash environment. The ONLY permitted root commands are: `npx`, `grep`, and `gradle` (for Android).
2. **Standard Unix Commands Will Fail**: Do not attempt to use `curl`, `wget`, `ls`, `cat`, `python`, `python3`, `sed`, `awk`, `chmod`, `rm`, or `mv` via the shell tool. They will instantly fail with an unrecognized command error. (Use the agent's built-in file system tools like list_dir, view_file, and delete_file instead of shell equivalents).
3. **The npx Loophole (Crucial for Network/Execution)**: Because `curl` and `python` are blocked, you must execute dynamic logic or network requests using Node via npx. To download a file: `npx -y node -e 'fetch("https://...").then(r=>r.text()).then(t=>require("fs").writeFileSync("file.ext", t))'`. To run scripts: Use `npx tsx script.ts` or `npx -y node script.js`.
4. **No Python Execution in the Agent Shell**: Even if the workspace contains Python scripts (like offline compilers or generators), the agent cannot execute them in its shell. Any Python execution must be done by the user locally on their own machine, or the logic must be translated to JS/TS to run via `npx tsx`.
5. **Interactive Prompts Cause Deadlocks**: The shell environment has no TTY (no interactive terminal for the user). If a command requires a [Y/n] confirmation, it will hang or fail. **Rule: Always forcefully bypass prompts.** (e.g., ALWAYS use `npx -y` instead of just `npx`).
6. **Long-Running/Background Tasks**: The shell tool cannot be used to run sleep commands or spawn daemonized background servers easily. If you need to wait for something, use the native agent schedule tool (cron/timers) rather than trying to hack a shell delay.

# ⚠️ CRITICAL CONTEXT: iOS a-Shell & a-Shell Mini Limitations
When writing Python scripts, shell commands, or architectures intended to run offline on iOS via **a-Shell** or **a-Shell mini**, you MUST strictly adhere to the following limitations we have discovered. Assume this is a highly restricted Alpine-like sandbox.

## 1. Zero External Dependencies (No PIL, No NPM, No C-Compilers)
*   **No Node.js / NPM**: `a-Shell mini` does not have a standalone Node package. Do not write solutions that rely on `npm install` or executing JavaScript.
*   **No C-Compilers (`clang`/`gcc`)**: You cannot compile C/C++ natively on the device.
*   **No C-Bound Python Libraries**: `pip install` works for pure Python, but anything requiring C-bindings (like `Pillow`/`PIL` for image manipulation) will fail to build. 
*   **Solution**: You must use the **pure Python standard library** for everything (e.g., parsing binary formats natively with `struct`). For heavy native binaries (like `xdelta3`), you must pre-compile them to WebAssembly (`.wasm`) using a WASI-SDK elsewhere, and then invoke them using a-Shell's native `wasm` command.

## 2. File System & Pathing Restrictions
*   **Virtual Mounting**: iOS restricts root file traversals. a-Shell uses virtual mounts (like `pickFolder`). 
*   **Broken Glob/Walk**: Scripts attempting to use `os.walk()` or globally scan file structures will frequently fail or hit permission boundaries.
*   **Solution**: You must firmly anchor all pathing to the script's origin directory using `os.path.dirname(os.path.abspath(__file__))`. Do not assume standard Windows/Linux relative architectures, and rely on single-file monolithic scripts where possible to prevent import chain snaps.

## 3. Header Corruption & Binary Mangling
*   **Mangled Headers**: Mobile OS export routines and a-Shell's file handling can horribly mangle standard binary headers. For example, standard `.bmp` exports on iOS often mutate into `BITMAPV4HEADER` structures with fake compression flags and massive negative dimensions (e.g., height = `-89039`).
*   **Solution**: **Fault tolerance > strict binary specifications**. Do not rely on header data. If you expect a specific width, hard-force it. Calculate the height mathematically based on the raw file size minus the data offset, rather than trusting the header bytes.
- **Swift String Interpolation Safety**: Never escape quotes inside Swift string interpolations. Swift 5+ supports unescaped quotes naturally. Writing \(\"%.1f\") will cause compiler crash (Exit Code 65). Always write \("%.1f").

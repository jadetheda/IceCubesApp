# Upstream Merge Ledger

Tracked record of commits evaluated and integrated from `Dimillian/IceCubesApp` into this fork.

Every upstream commit reviewed must be logged here with its true status:
- `MERGED`: Code compiles in CI, functions as intended, and remains in the active tree.
- `EXCLUDED`: Skipped or stripped out due to compiler incompatibilities, unreleased SDKs, or architectural conflicts.
- `REVERTED`: Previously merged but rolled back after causing build breaks or runtime failures.
- `REDUNDANT`: Already authored or implemented in our fork prior to upstream merge.

---

## Batch 1: Upstream v2.1.5 - v2.1.7 (`b2db3033...98098b9c`)

- **Range:** `b2db3033fbf67a97b54d25d6dac2df8a029b26b1...98098b9c`
- **Evaluated:** 20 commits
- **Merged:** 17 commits
- **Redundant (Pre-existing in fork):** 1 commit
- **Excluded:** 2 commits
- **Reverted:** 0 commits

### Summary Table

| Commit SHA | Author | Title / Area | Status | Target Files | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `5b52eb97` | Ivan Magda | Stop posting progress timer | `MERGED` | `EditorStore.swift`, `EditorStoreTests.swift` | Assigns `postingTimer` so `defer` invalidates the 20 Hz tick. |
| `ddadbfc8` | Ivan Magda | Next-page cursor for block/mute | `MERGED` | `Accounts.swift`, `AccountsListViewModel.swift`, `AccountsPaginationTests.swift` | Passes `maxId` query param to unstick pagination past page 1. |
| `7c7d3926` | Thomas Ricouard | Fix composer sheet freeze | `MERGED` | `AccessoryView.swift` | Adds `ViewThatFits(in: .horizontal)` to prevent layout loop. |
| `5782d683` | Thomas Ricouard | Filter trailing-dot server aliases | `MERGED` | `InstanceSocialClient.swift`, `InstanceSocialClientTests.swift` | Filters entries like `mastodon.social.` from login suggestions. |
| `6d6b954f` | Nas | Restore `%@` in Polish & Catalan | `MERGED` | `Localizable.xcstrings` | Restores missing placeholder tokens. |
| `cb4ca916` | Joe Barbere | Collections notifications | `MERGED` | `Models/Notification.swift`, `NotificationsListDataSource.swift`, `NotificationRowCollectionView.swift`, `CollectionNotificationTests.swift` | Adapted: preserved `nonisolated` label methods and decoupled view hierarchy. |
| `26a86b6e` | Thomas Ricouard | Compact tab order on iPhone | `MERGED` | `AppView.swift` | Adapted: preserved `availableTabs(for:)` backend capability filter for Misskey/IceShrimp. |
| `0eb5f335` | Thomas Ricouard | Catalyst avatar button style | `MERGED` | `ToolbarTab.swift` | Uses `.buttonStyle(.plain)` for Mac Catalyst avatar button. |
| `12c21ed8` | Thomas Ricouard | Catalyst navigation bar blur | `MERGED` | `Tabs.swift`, `NotificationTab.swift`, `TimelineView.swift` | Preserves navigation material. Manually applied around TimelineView masonry. |
| `b558bd09` | jadetheda | Custom server emojis in headers | `REDUNDANT` | `AccountSettingView.swift`, `AccountDetailToolbar.swift` | User's upstream PR #2496; already present across 8 views in fork. |
| `fb232d3d` | Thomas Ricouard | Bump SwiftSoup to 2.13.9 | `MERGED` | `Package.resolved` | SPM dependency bump. |
| `61ce3cc7` | Thomas Ricouard | Bump LRUCache to 1.3.0 | `MERGED` | `Package.resolved` | SPM dependency bump. |
| `c3a852fd` | Thomas Ricouard | Bump swiftui-introspect to 26.0.2 | `MERGED` | `Package.resolved`, `Timeline/Package.swift` | SPM dependency bump. |
| `9bea9659` | Thomas Ricouard | Bump purchases-ios-spm to 5.89.0 | `MERGED` | `Package.resolved` | RevenueCat SDK dependency bump. |
| `0bfbf47a` | Thomas Ricouard | Bump wishkit-ios to 5.2.1 | `MERGED` | `Package.resolved` | SPM dependency bump. |
| `2ad6e689` | Thomas Ricouard | Bump version to 2.1.5 | `MERGED` | `project.pbxproj` | Superseded by 2.1.7. |
| `f2ec6c1c` | Thomas Ricouard | Bump version to 2.1.6 | `MERGED` | `project.pbxproj` | Superseded by 2.1.7. |
| `98098b9c` | Thomas Ricouard | Bump version to 2.1.7 | `MERGED` | `project.pbxproj` | Marketing version updated to 2.1.7. |
| `9efcb16e` | Thomas Ricouard | Adaptive sidebar on unfolded Duo | `EXCLUDED` | `AppView.swift` | Relies on `defaultTabBarPlacement(...)`. Fails compilation on Xcode SDK (Exit Code 65). |
| `5c91bd28` | Thomas Ricouard | Duo vertical toolbar alignment | `EXCLUDED` | `ToolbarTab.swift` | Relies on `.axisBehavior(.verticalPreferred)` and `\.toolbarVerticalEdge`. Fails compilation on Xcode SDK (Exit Code 65). |

---

## Detailed Exclusion Records

### `9efcb16e` — Adaptive sidebar on unfolded Duo screens
- **Upstream Commit:** `9efcb16e5349c719875e5330aa1ee8c20577dae7`
- **Upstream PR:** #2512
- **Author:** Thomas Ricouard
- **Failure Symptom:** GitHub Actions run `38991252955` failed at 7m10s with:
  ```text
  AppView.swift:66:14: error: value of type 'some View' has no member 'defaultTabBarPlacement'
  ```
- **Root Cause:** Uses `defaultTabBarPlacement(preferredTabBarPlacement)` with `preferredTabBarPlacement: AdaptableTabBarPlacement`. Although wrapped in `#available(iOS 27.0, visionOS 27.0, *)`, Swift resolves symbol names at compile time. The public Apple SDKs provided on GitHub Actions runners (Xcode 15 / 16) do not contain `defaultTabBarPlacement` or `AdaptableTabBarPlacement`.
- **Action Taken:** Removed the `.defaultTabBarPlacement` modifier and the helper property from `AppView.swift`. Retained standard `.tabViewStyle(.sidebarAdaptable)`.
- **Status:** `EXCLUDED`. Not counted as merged.

### `5c91bd28` — Duo vertical toolbar alignment
- **Upstream Commit:** `5c91bd283c8ae99d14ea1743a4928e4e7ee87796`
- **Upstream PR:** #2511
- **Author:** Thomas Ricouard
- **Failure Symptom:** GitHub Actions run `38991252955` failed at 7m10s with:
  ```text
  ToolbarTab.swift:39:16: error: value of type 'some ToolbarContent' has no member 'axisBehavior'
  ToolbarTab.swift:100:4: error: cannot infer key path \.toolbarVerticalEdge
  ```
- **Root Cause:** Applies `.axisBehavior(.verticalPreferred)` and uses `@Environment(\.toolbarVerticalEdge)` inside a custom `ToolbarAvatarAlignment` modifier guarded by `#available(iOS 27.1, *)`. These SDK members are unreleased internal/future APIs not present in public Xcode releases.
- **Action Taken:** Removed `.axisBehavior` and the `ToolbarAvatarAlignment` modifier. Preserved standard iOS `.offset(x: -12)` and Catalyst plain button style.
- **Status:** `EXCLUDED`. Not counted as merged.

---

## Rules for Future Merges

1. **Verify Before Declaring Merged:** Never mark an upstream commit as `MERGED` until a clean CI build succeeds with the code intact.
2. **Track Discarded Code Honestly:** If an upstream commit's changes must be discarded or commented out due to compile errors, SDK mismatches, or solver traps, mark it `EXCLUDED`.
3. **Log Reversions:** If code passes initial review but subsequently breaks builds or causes regressions in testing, mark it `REVERTED` with a link to the revert commit and the exact error log.
4. **Document Architectural Adaptations:** When upstream code touches areas heavily modified in our fork (such as AST-decoupled views, custom themes, multi-backend adapters, or Gallery Mode), detail how the conflict was resolved.

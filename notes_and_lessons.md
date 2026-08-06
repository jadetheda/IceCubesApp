# Notes & Lessons

- **FAILED ATTEMPT**: Tried fixing Gallery Mode scroll jumping by restoring `scrollToIdAnimated` to `viewModel.lastTopVisibleStatusId` after a 0.5s delay. IT DID NOT WORK.
  - **Reason**: The `GalleryStatusesListView` sets its row IDs to `mediaStatus.id` (which is `attachment.id`), NOT `status.id`. So scrolling to `lastTopVisibleStatusId` did nothing when entering Gallery Mode.
  - **Solution**: We must calculate `lastTopVisibleMediaStatusId` by finding the first visible status with media, and grabbing its `mediaAttachments.first?.id`. When `isGalleryMode` becomes true, we `proxy.scrollTo(lastTopVisibleMediaStatusId)`. When it becomes false, we `proxy.scrollTo(lastTopVisibleStatusId)`.

- **COMPILER CRASH (Exit Code 65) & Bindable Lookup**: In SwiftUI `@Observable` classes, stored properties with observers (`didSet`) but no initial value at their declaration site can fail to participate in `Bindable`'s dynamic member lookup, causing key path resolution failures in compilation (e.g. `Bindable<UserPreferences> has no dynamic member 'hideInteractionButtons'`).
  - **Solution**: Convert these properties into computed properties that get/set their values directly from/to `storage` or backings, explicitly triggering SwiftUI updates using `access(keyPath:)` and `withMutation(keyPath:)`. Ensure you call `withMutation` nested or sequential if other cross-dependent observed properties must also update. Remove their assignments in `init()`.

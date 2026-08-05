# Notes & Lessons

- **FAILED ATTEMPT**: Tried fixing Gallery Mode scroll jumping by restoring `scrollToIdAnimated` to `viewModel.lastTopVisibleStatusId` after a 0.5s delay. IT DID NOT WORK.
  - **Reason**: The `GalleryStatusesListView` sets its row IDs to `mediaStatus.id` (which is `attachment.id`), NOT `status.id`. So scrolling to `lastTopVisibleStatusId` did nothing when entering Gallery Mode.
  - **Solution**: We must calculate `lastTopVisibleMediaStatusId` by finding the first visible status with media, and grabbing its `mediaAttachments.first?.id`. When `isGalleryMode` becomes true, we `proxy.scrollTo(lastTopVisibleMediaStatusId)`. When it becomes false, we `proxy.scrollTo(lastTopVisibleStatusId)`.

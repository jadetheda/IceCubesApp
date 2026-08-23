# Gallery Mode Refactor Plan (CLAUDE.md Compliance)

## The Upstream vs Custom Architecture Discovery
After cloning the upstream Dimillian repository, we found a crucial distinction:
- **Upstream Legacy:** The `StatusesFetcher` protocol and `StatusesListView` are part of Dimillian's original legacy architecture. `CLAUDE.md` explicitly states to "Maintain existing patterns in legacy code". Ripping out `StatusesFetcher` across the entire app would be a massive overstep and rewrite of Dimillian's core timeline logic.
- **Our Custom Violation:** However, when we created `GalleryStatusesListView`, we built it identically to `StatusesListView` by making it generic over `<Fetcher: StatusesFetcher>`. Because of this tight coupling, when we wanted to use the masonry gallery on the User Profile Media tab, we were forced to invent a brand new custom ViewModel (`AccountMediaFetcher`) just to satisfy the generic constraint!
- **The Verdict:** Creating `AccountMediaFetcher` was a direct violation of the `CLAUDE.md` rule: "New features should NOT use ViewModels".

## The Refactor Strategy

### 1. Decouple `GalleryStatusesListView` from `StatusesFetcher`
We will rewrite `GalleryStatusesListView` so that it is no longer generic over `StatusesFetcher`. Instead, it will be a pure, "dumb" SwiftUI component:
```swift
public struct GalleryStatusesListView: View {
  let statuses: [Status]
  let statusesState: StatusesState
  var fetchNextPage: () async -> Void
  // ...
}
```
*Why?* This allows the Gallery to be used anywhere, whether the parent view is using a legacy ViewModel or a modern SwiftUI `@State`.

### 2. Eradicate our custom `AccountMediaFetcher` ViewModel
Because `GalleryStatusesListView` will no longer require a `StatusesFetcher`, we can completely delete `AccountMediaFetcher.swift`. 
We will restore `AccountDetailMediaGridView` to its original, modern `@State`-driven architecture (as it was in upstream), but swap its basic rigid `LazyVGrid` for our beautiful masonry `GalleryStatusesListView`.

### 3. Gracefully Bridge the Legacy Views
For the existing timeline views that still use Dimillian's legacy `StatusesFetcher` (like `TimelineListView`, `AccountStatusesListView`, `AnyStatusesListView`), we will simply pass their `fetcher.statuses` and `fetcher.fetchNextPage` into the newly decoupled `GalleryStatusesListView`. 

This satisfies all constraints:
- We don't rewrite Dimillian's legacy timeline fetching architecture.
- We destroy the custom ViewModel we illegally created.
- We make the Gallery component fully compliant with modern pure-state SwiftUI.

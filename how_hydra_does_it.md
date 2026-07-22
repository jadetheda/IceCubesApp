# How Hydra Implements Masonry / Gallery Mode

Hydra is a React Native app built around the Reddit API (a clone of Apollo). When implementing its "Gallery Mode" / Masonry layout, it relies heavily on `@shopify/flash-list`.

## Key Findings

1. **The Technology Stack:**
   - Hydra is a React Native application (written in `.tsx`), not a native Swift/SwiftUI application.
   - For its Masonry layout, it uses **`@shopify/flash-list`**, a highly optimized list component for React Native that supports masonry layouts out-of-the-box via a `MasonryFlashList` component or by passing `masonry={true}`.

2. **FlashList Configuration:**
   - Hydra sets `masonry={true}` and `numColumns={2}` on a standard `<FlashList>`.
   - It also enables `optimizeItemArrangement={true}`. This is a crucial feature of FlashList's masonry layout: it allows the layout algorithm to slightly reorder items to fill gaps, minimizing the uneven heights of columns at the bottom of the list.

3. **Deterministic Heights (The Core Secret):**
   - The most critical aspect of Hydra's (and FlashList's) masonry success is that item dimensions are calculated **deterministically before rendering**.
   - In `components/UI/Gallery/GalleryComponent.tsx`, Hydra calculates the exact width and height of every item using the screen width and the media's aspect ratio:
     ```typescript
     width: contentDimensions.width / 2,
     height: contentDimensions.width / 2 / item.mediaAspectRatio,
     ```
   - Because the exact height of every item is known immediately (based on metadata from the Reddit API), FlashList's layout manager can pre-calculate the total height of all columns and assign items to the shortest column without waiting for images to load or relying on asynchronous layout passes.

4. **Pagination and Media Filtering:**
   - Hydra filters the Reddit posts on the client-side to extract only media items (images/videos) into a flat `galleryMedia` array.
   - It uses FlashList's native `onEndReached` callback to trigger pagination. Because the FlashList handles virtualization and layout natively, it correctly determines when the user is nearing the end of the content, avoiding the "infinite fetch loop" issues we've seen in SwiftUI when nesting `NextPageView` improperly.

## Application to IceCubesApp (SwiftUI)

Since SwiftUI (as of iOS 17) lacks a native `Masonry` or `StaggeredGrid` component with virtualized recycling comparable to `FlashList`:

1. **Pre-calculated Heights are Mandatory:** Just like Hydra relies on `mediaAspectRatio` to calculate heights upfront, our SwiftUI implementation must ensure columns know exactly how tall an image will be before it loads. If SwiftUI has to wait for the image to load to expand the column, the column heights are constantly changing dynamically, leading to elements jumping between columns, massive gaps, and layout jitter.
2. **True Lazy Evaluation vs VStack:** FlashList handles recycling natively. In our custom SwiftUI masonry layout (which uses an `HStack` of `VStack` columns), we do not get true cell recycling. Wrapping the entire grid in a `LazyVStack` helps defer the `NextPageView` pagination trigger, but the columns themselves must avoid infinite-height growth glitches (like the `.aspectRatio(1, contentMode: .fill)` issue we fixed earlier).

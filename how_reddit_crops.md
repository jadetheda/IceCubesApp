# Reddit API Thumbnail Cropping Mechanics

When investigating how Reddit determines the cropping behavior for thumbnails, we find that the Reddit thumbnail generator imposes strict aspect ratio and height caps on its pre-rendered resolution buckets.

## The `resolutions` Array
When a post contains an image, the Reddit API provides a `preview` object with a `source` (the full original image) and a `resolutions` array. The `resolutions` array contains downscaled versions of the image at standardized widths (e.g., 108, 216, 320, 640, 960, 1080 pixels).

## The Cropping Threshold
For standard images, the height is scaled proportionally to match the standard width. However, for extremely tall images (like comics, long screenshots, or infographics):

1. **Max Height Cap**: The Reddit media processing backend enforces a maximum pixel height for each resolution bucket to prevent generating excessively large files or breaking UI bounds.
2. **The 1:2.5 / 1:3 Rule**: Typically, Reddit caps the height of a thumbnail so that the aspect ratio does not exceed a certain threshold (often around `1:2.5` to `1:4` depending on the bucket). 
3. **Example**: If a user uploads a 1080x10800 image (aspect ratio `0.1` or `1:10`):
   - The original `source` will accurately report `width: 1080, height: 10800`.
   - The lowest resolution thumbnail (108px wide bucket) should theoretically be `108x1080`.
   - However, Reddit's processor caps the height (e.g., at 216px or 320px). The thumbnail `url` will point to a cropped version of the image, and the API will report its dimensions as something like `width: 108, height: 216` (an aspect ratio of `0.5`).

## How this affects Hydra
Hydra relies on this lowest-resolution thumbnail to calculate its masonry cell heights:
```typescript
mediaAspectRatio = images[0][0].width / images[0][0].height;
```
Because `images[0][0]` refers to the 108px bucket, Hydra inadvertently inherits Reddit's server-side height clamp. 
- A normal photo (1080x1080, AR 1.0) gets a 108x108 thumbnail (AR 1.0). Hydra renders a square.
- A tall infographic (1080x10800, AR 0.1) gets a 108x216 thumbnail (AR 0.5). Hydra renders it as a 1:2 rectangle, effectively clamping the height and preventing the masonry column from being dominated by a single massive item.

## Why this is brilliant (accidentally or intentionally)
If Hydra had calculated the aspect ratio using the original `source` dimensions, extremely tall images would consume multiple screens of vertical space within a single masonry column, completely destroying the Gallery view experience. By relying on Reddit's thumbnail crops, Hydra gets a visually uniform, "clamped" gallery where long images are naturally constrained.

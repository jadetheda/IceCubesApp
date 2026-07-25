# Issues

## Pending (some fresh, some stale)

### Corrections

- [ ] The open source software credits are formatted incorrectly now (check the old version)

### Gallery Mode & Media Layout Enhancements

- [ ] Check if the pagination logic still hardcodes the number 6 — when surely this number should be dynamic based on how many columns you have enabled? Basically even how much fits on screen at one time, so like maybe on iPad or something it would be different

### Bugs/Regressions

- [ ] The background of the Gallery Mode doesn't match the background of the theme
- [ ] Gallery Mode in the Media tab in Profile doesn't support remote media fallback -- nor does the version inside its Fullscreen Gallery view (aka what used to be called Media Grid)
- [ ] We appear to have somehow broken the fix implemented earlier to address posts not showing as interacted with after leaving the view.
- [ ] The counter is showing posts I can't see? Maybe scrolling up is still broke
- [ ] Undo Scroll to Top only works in certain tabs. Ideally it should work in all.
- [ ] Boosts aren't being correctly detected as the same post as the original it seems (at least on Local, and at least when they're my own boosts) 
- [ ] ACTUALLY, if they're my own boost, they should just always be hidden as Seen

### Features

- [ ] I rather hate how the post view (at least on iOS(?)) crops the images to like 5:4 whether there are multiple images. There should be a setting to turn that off!
- [ ] Add dropdown to change the IceShrimp trending algorithm between the Mastodon algorithm and a simple Sort by Highest for the past day (like Reddit)
- [ ] Make Match System in themes also switch between the light and dark variant of themes depending on which your device is selected
- [ ] Maybe: long-press profile tab to open profile switcher
- [ ] Add status.server to instance info
- [ ] toggle to set separate custom theme settings for light/dark
- [ ] easy probably: Animated emojis
- [ ] optional (off by default) button in timeline menu to hide the pinned items temporarily 

### App Configuration & Maintenance

- [ ] Put Cached Server Emojis count below the Cached Posts counter in Settings > Account. Also include below the Clear Cache button a toggle to turn off the cache emotes feature. 
- [ ] Figure out where *the second home* of the various **Experimental Settings** should be once they're finished

### Stretch goals
- [ ] **New feature:** Japanese auto-translate. Detect when a post contains more than **5 Japanese or Chinese characters**, and if the user has configured the **DeepL API**, automatically trigger translation for the post.
- [ ] If I load a user's profile and it comes back completely empty, we should fetch the profile content directly from the instance they belong to. **Phanpy does this, we should investigate how.**


## Absolute Pipedreams
- [ ] **Extra Stretchy goal:** Investigate what would be required to support **Akkoma**, **Sharkey**, and/or **PixelFed**.
- [ ] Fix whatever causes the iOS 26 automatic collapse ellipsis to just never, ever work -- even upstream. *Well, i think it did work one time... like 6 months ago*

---

# Completed

## Bugs & Corrections

- [x] **Bug:** The **"Media-Only Toggle in Timeline Menu"** option is incorrectly labeled. **"Media-Only"** should read **"Gallery Mode"**.
- [x] **Bug:** Gallery Mode is broken in the **Lists** tab. It does the old thing the Timeline tab's Gallery Mode used to, where it assumes there's no more content if the next page fetched doesn't have any media. Fix this bug. Also, something should probably be done about code fragmentation in how Gallery Mode is implemented across the app.
- [x] **Bug:** Scrolling to the bottom of a person's **Media** section in their profile while **Hide Read Posts** is enabled (at least in Gallery Mode) triggers a refresh and hides a bunch of posts out from under you.
- [x] In the implementation of Gallery Mode within profiles, the load remote media features which are present in the Timeline tab are completely non-functional, they just fail to load and don't even try to do anything else.
- [x] **change:** The caching of server emote images should have an option to toggle it off, in case someone's tight on storage.
- [x] **Bug:** **View Local Timeline** no longer appears in the post context menu when you're already viewing that user's Local Timeline. The **Content Filter** button remains desired, but should appear in its own section at the bottom of the menu, matching the Timeline menu.
- [x] We should remove the **Load Remote Media button** as its role has been superseded by the **automatic remote fallback** and **IceShrimp** **force Video fallback** features
- [x] Move the **Experimental Settings** section above the **General** section in **Settings**
- [x] "Ice Cube is built with the following open-source software" seems like it may be outdated, i think we've introduced new dependencies since then. Not sure.
- [x] **Somehow *Hide Seen Posts* is completely broken now. I keep seeing posts again and again across different sections, and the button does nothing.**
- [x] **Big Bug:** The custom ellipsis menu, which is supposed to be exclusive to the **Lists** tab, now shows up in the **Timeline** tab's header when a list is selected, replacing the dynamic ellipsis menu generated by iOS 26.
- [x] Coming out of Gallery Mode seems to jettison us to the top of the page.
- [x] Gallery Mode just doesn't load at all within the reposts tab in profiles

## Gallery Mode & Media Layout Enhancements

- [x] **Broken feature:** In the **Media** tab on a user's page, replace **Media Grid** with **Gallery Mode**. It should still be called **Media Grid**, but opening it should launch the Gallery Mode masonry layout we've built. We tried to do this already, but it apparently didn't work.
- [x] The maximum gallery mode image height is way too small. **Hydra IS THE GALLERY MODE GOLD STANDARD and we should use their code as a guide for our implementation!** At the very least, set it as was higher.
- [x] Figure out how Hydra handles its gallery mode -- hell, maybe we can even (WITH CREDIT), borrow some of their code. 
- [x] **Enhancement:** When Gallery Mode is enabled on profile pages, **Pinned Posts** now also display using the Gallery Mode masonry layout while still retaining their own 'pinned' section.
- [x] OptimizeItemLayout=false option in experimental settings under gallery mode (in case people wanna disable the moving around)?
- [x] Ability to turn on thin lil margins on either side of gallery mode
- [x] Gallery Mode Page jumping in profiles, keeps shooting me back up to the bio
- [x] Option (enabled by default) to round the edges of the images in Gallery Mode (for similarity to the rest of the UI)

## Features

- [x] **Broken feature:** Tapping on the tab you're jn sends you to the top of the page. Tapping it again should return you to your previous position, effectively acting as an undo for accidental taps. This should expire after **10 seconds** by default, with the timeout configurable under **Experimental Features**. **We attempted to implement this, but it isn't working.**
- [x] Investigate how Mastodon's open source code (which u should credit in attributions.md if you use) determines what is "Trending". IceShrimp does not support this feature on a server-level, so I'd like to have a toggle under IceShrimp workarounds which implements it on the client level. I'm not sure how their algorithm works -- maybe it's a simple sort by faves/boosts for a given time period thing, or maybe they have some complex thing like Reddit does for "Hot" and whatnot. Who knows? Hopefully you!

---

# The Cutting Room Floor
*(completed items that got deleted along the way instead of staying archived)*

- [x] Removed the unnecessary **Display Mode** dropdown from a user's **…** menu.
- [x] **View Local Timeline** on a user's **…** menu now appears **below** the **Message** action instead of at the top.
- [x] Server emote caching now works as intended.
- [x] **Enhancement:** Gallery Mode on profiles is now full-width.
- [x] **Enhancement:** Added a **…** menu to the **Lists** tab (next to the compose button) containing the **Gallery Mode** toggle and the **Content Filter** popup, matching the Timeline tab.
- [x] Removed the option to disable **"Require media to be loaded [to be detected as Seen]"**, since this should always remain enabled.
- [x] Updated the app version to **2.1.4.4** in both the app metadata and the in-app **Settings** menu.

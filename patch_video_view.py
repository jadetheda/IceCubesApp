import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'r') as f:
    content = f.read()

# Update signature
content = content.replace(
    'func preparePlayer(autoPlay: Bool, isCompact: Bool) {',
    'func preparePlayer(autoPlay: Bool, isCompact: Bool, loopVideo: Bool) {'
)

# Update playback end observer
content = content.replace(
    'if autoPlay || self.forceAutoPlay {',
    'if loopVideo || self.forceAutoPlay {'
)

# Update the call in .onAppear
content = content.replace(
    """        viewModel.preparePlayer(
          autoPlay: isFullScreen ? true : preferences.autoPlayVideo,
          isCompact: isCompact)""",
    """        viewModel.preparePlayer(
          autoPlay: isFullScreen ? true : preferences.autoPlayVideo,
          isCompact: isCompact,
          loopVideo: isFullScreen ? true : preferences.loopVideo)"""
)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'w') as f:
    f.write(content)

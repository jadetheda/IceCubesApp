import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'r') as f:
    content = f.read()

# 1. Remove forceAutoPlay from the looping check
content = content.replace(
    'if loopVideo || self.forceAutoPlay {',
    'if loopVideo {'
)

# 2. Make the fullscreen cover obey the preference instead of forcing true
content = content.replace(
    'loopVideo: isFullScreen ? true : preferences.loopVideo)',
    'loopVideo: preferences.loopVideo)'
)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'w') as f:
    f.write(content)

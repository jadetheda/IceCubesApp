import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'r') as f:
    content = f.read()

content = content.replace(
    'if self.loopVideo || self.forceAutoPlay {',
    'if self.loopVideo {'
)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'w') as f:
    f.write(content)

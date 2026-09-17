import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'r') as f:
    content = f.read()

# Add loopVideo to the class
content = content.replace(
    'var isPlaying: Bool = false',
    'var isPlaying: Bool = false\n  var loopVideo: Bool = false'
)

# In preparePlayer, save loopVideo and fix observer
old_prepare = """    playbackEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: player.currentItem, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        if loopVideo {
          self.play()
        }
      }
    }"""

new_prepare = """    self.loopVideo = loopVideo
    playbackEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: nil, queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        guard let self = self, 
              let item = notification.object as? AVPlayerItem, 
              item == self.player?.currentItem else { return }
        if self.loopVideo || self.forceAutoPlay {
          self.play()
        }
      }
    }"""

content = content.replace(old_prepare, new_prepare)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'w') as f:
    f.write(content)

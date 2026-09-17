import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'r') as f:
    content = f.read()

# Fix preparePlayer
old_prepare = """    self.loopVideo = loopVideo
    playbackEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: nil, queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        guard let self = self, 
              let item = notification.object as? AVPlayerItem, 
              item == self.player?.currentItem else { return }
        if self.loopVideo {
          self.play()
        }
      }
    }"""

new_prepare = """    self.loopVideo = loopVideo
    playbackEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: player.currentItem, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        if self.loopVideo {
          self.play()
        }
      }
    }"""

content = content.replace(old_prepare, new_prepare)

# Fix setupObserver
old_setup = """            let newItem = AVPlayerItem(asset: fallbackAsset)
            self.player?.replaceCurrentItem(with: newItem)
            self.setupObserver(for: newItem)
            if wasPlaying {"""

new_setup = """            let newItem = AVPlayerItem(asset: fallbackAsset)
            self.player?.replaceCurrentItem(with: newItem)
            self.setupObserver(for: newItem)
            
            if let playbackEndObserver = self.playbackEndObserver {
              NotificationCenter.default.removeObserver(playbackEndObserver)
            }
            self.playbackEndObserver = NotificationCenter.default.addObserver(
              forName: .AVPlayerItemDidPlayToEndTime,
              object: newItem, queue: .main
            ) { [weak self] _ in
              Task { @MainActor in
                guard let self else { return }
                if self.loopVideo { self.play() }
              }
            }
            
            if wasPlaying {"""

content = content.replace(old_setup, new_setup)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIAttachmentVideoView.swift', 'w') as f:
    f.write(content)

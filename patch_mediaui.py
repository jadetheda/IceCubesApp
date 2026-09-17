import re

with open('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'r') as f:
    content = f.read()

content = content.replace(
    '  public init(selectedAttachment: MediaAttachment, attachments: [MediaAttachment], useRemoteMedia: Bool = false) {',
    '  @MainActor\n  public init(selectedAttachment: MediaAttachment, attachments: [MediaAttachment], useRemoteMedia: Bool = false) {'
)

content = content.replace(
    '  init?(from attachment: MediaAttachment, useRemoteMedia passedUseRemoteMedia: Bool = false) {',
    '  @MainActor\n  init?(from attachment: MediaAttachment, useRemoteMedia passedUseRemoteMedia: Bool = false) {'
)

with open('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'w') as f:
    f.write(content)

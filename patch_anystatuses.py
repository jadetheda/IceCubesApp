import re

with open('Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift', 'r') as f:
    text = f.read()

text = text.replace(
    '  let showFilterWarning: Bool',
    '  let showFilterWarning: Bool\n  let supportsGalleryMode: Bool'
)

text = text.replace(
    '    showFilterWarning: Bool = true\n  ) {',
    '    showFilterWarning: Bool = true,\n    supportsGalleryMode: Bool = true\n  ) {'
)

text = text.replace(
    '    self.showFilterWarning = showFilterWarning',
    '    self.showFilterWarning = showFilterWarning\n    self.supportsGalleryMode = supportsGalleryMode'
)

text = text.replace(
    '    if isMediaTab || contentFilter.isGalleryMode {',
    '    if isMediaTab || (supportsGalleryMode && contentFilter.isGalleryMode) {'
)

text = text.replace(
    '      isForceGalleryMode: isMediaTab',
    '      isForceGalleryMode: isMediaTab || (supportsGalleryMode && contentFilter.isGalleryMode)'
)

with open('Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift', 'w') as f:
    f.write(text)

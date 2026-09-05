import re

with open('Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift', 'r') as f:
    glv = f.read()

# Remove the GalleryStatusesListView struct
start = glv.find('@MainActor\npublic struct GalleryStatusesListView: View {')
end = glv.find('@MainActor\npublic struct GalleryMediaCell: View {')

if start != -1 and end != -1:
    glv = glv[:start] + glv[end:]
    with open('Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift', 'w') as f:
        f.write(glv)

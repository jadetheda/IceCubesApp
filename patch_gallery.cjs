const fs = require('fs');
const file = 'Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
  `        if mediaStatuses.isEmpty {
          currentAnchors.append(status.id)
        } else {
          for (index, mediaStatus) in mediaStatuses.enumerated() {
            galleryNodes.append(GalleryNode(
              id: mediaStatus.id,
              mediaStatus: mediaStatus,
              anchorIds: index == 0 ? currentAnchors : []
            ))
            if index == 0 { currentAnchors = [] }
          }
        }`,
  `        if mediaStatuses.isEmpty {
          currentAnchors.append(status.id)
        } else {
          for (index, mediaStatus) in mediaStatuses.enumerated() {
            var anchors = index == 0 ? currentAnchors : []
            if index == 0 { anchors.append(status.id) }
            galleryNodes.append(GalleryNode(
              id: mediaStatus.id,
              mediaStatus: mediaStatus,
              anchorIds: anchors
            ))
            if index == 0 { currentAnchors = [] }
          }
        }`
);

fs.writeFileSync(file, content);

const fs = require('fs');
const file = 'Packages/Timeline/Sources/Timeline/View/TimelineViewModel.swift';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
  `  var lastTopVisibleStatusId: String?
  var lastTopVisibleMediaStatusId: String?`,
  `  var lastTopVisibleStatusId: String?`
);

content = content.replace(
  `  private func updateLastTopVisibleStatusId() {
      if let id = getTopVisibleStatusId() {
          lastTopVisibleStatusId = id
          
          // Also find the first visible media status
          if case .displayWithGaps(let items, _) = statusesState {
              if let mediaId = items.compactMap({ $0.status }).first(where: { visibleStatusesCount[$0.id] != nil && !$0.mediaAttachments.isEmpty })?.id {
                  lastTopVisibleMediaStatusId = mediaId
              }
          } else if case .display(let statuses, _) = statusesState {
              if let mediaId = statuses.first(where: { visibleStatusesCount[$0.id] != nil && !$0.mediaAttachments.isEmpty })?.id {
                  lastTopVisibleMediaStatusId = mediaId
              }
          }
      }
  }`,
  `  private func updateLastTopVisibleStatusId() {
      if let id = getTopVisibleStatusId() {
          lastTopVisibleStatusId = id
      }
  }`
);

fs.writeFileSync(file, content);

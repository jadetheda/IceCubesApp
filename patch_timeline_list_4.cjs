const fs = require('fs');
const file = 'Packages/Timeline/Sources/Timeline/View/TimelineListView.swift';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
  `        if oldValue != newValue {
            let targetId = newValue ? viewModel.lastTopVisibleMediaStatusId : viewModel.lastTopVisibleStatusId
            if let targetId = targetId ?? viewModel.lastTopVisibleStatusId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToIdAnimated = targetId
                }
            }
        }`,
  `        if oldValue != newValue {
            if let targetId = viewModel.lastTopVisibleStatusId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToIdAnimated = targetId
                }
            }
        }`
);

fs.writeFileSync(file, content);

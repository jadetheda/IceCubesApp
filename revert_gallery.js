const fs = require('fs');
let content = fs.readFileSync('Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift', 'utf8');

const search = `    ForEach(chunks) { chunk in
      Group {
        if chunk.isGap, let gap = chunk.gap {
          if let gapLoader = fetcher as? GapLoadingFetcher {
            TimelineGapView(gap: gap) {
              await gapLoader.loadGap(gap: gap)
            }
            .padding(.horizontal, .layoutPadding)
            .padding(.vertical, 8)
          }
        } else {
          makeGridChunk(for: chunk.items)
        }
      }
      .listRowBackground(theme.primaryBackgroundColor)
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      .listRowSeparator(.hidden)
    }`;

const replace = `    ForEach(chunks) { chunk in
      VStack(spacing: 0) {
        if chunk.isGap, let gap = chunk.gap {
          if let gapLoader = fetcher as? GapLoadingFetcher {
            TimelineGapView(gap: gap) {
              await gapLoader.loadGap(gap: gap)
            }
            .padding(.horizontal, .layoutPadding)
            .padding(.vertical, 8)
          }
        } else {
          makeGridChunk(for: chunk.items)
        }
      }
    }`;

if (content.includes(search)) {
    fs.writeFileSync('Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift', content.replace(search, replace));
    console.log('Success gallery');
} else {
    console.log('Not found gallery');
}

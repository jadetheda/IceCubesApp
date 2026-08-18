const fs = require('fs');

// Patch 1: AccountStatusesListView.swift
let content1 = fs.readFileSync('Packages/Account/Sources/Account/StatusesLists/AccountStatusesListView.swift', 'utf8');
const search1 = `      if TimelineContentFilter.shared.isGalleryMode {
        ScrollView {
          LazyVStack(spacing: 0) {
            GalleryStatusesListView(fetcher: fetcher, client: client, routerPath: routerPath)
          }
        }
      } else {`;
const replace1 = `      if TimelineContentFilter.shared.isGalleryMode {
        List {
          GalleryStatusesListView(fetcher: fetcher, client: client, routerPath: routerPath)
        }
        .listStyle(.plain)
        .environment(\\.defaultMinListRowHeight, 1)
      } else {`;
if (content1.includes(search1)) {
    fs.writeFileSync('Packages/Account/Sources/Account/StatusesLists/AccountStatusesListView.swift', content1.replace(search1, replace1));
    console.log('Success 1');
} else {
    console.log('Not found 1');
}

// Patch 2: AccountDetailMediaGridView.swift
let content2 = fs.readFileSync('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', 'utf8');
const search2 = `    ScrollView {
      LazyVStack(spacing: 0) {
        // Reuse the exact same masonry gallery implementation from the Timeline
        // This eliminates layout bugs and standardizes remote-media behavior.
        GalleryStatusesListView(
          fetcher: fetcher,
          client: client,
          routerPath: routerPath,
          isRemote: isRemote
        )
      }
      .padding(.top, .layoutPadding)
    }`;
const replace2 = `    List {
      // Reuse the exact same masonry gallery implementation from the Timeline
      // This eliminates layout bugs and standardizes remote-media behavior.
      GalleryStatusesListView(
        fetcher: fetcher,
        client: client,
        routerPath: routerPath,
        isRemote: isRemote
      )
    }
    .listStyle(.plain)
    .environment(\\.defaultMinListRowHeight, 1)`;
if (content2.includes(search2)) {
    fs.writeFileSync('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', content2.replace(search2, replace2));
    console.log('Success 2');
} else {
    console.log('Not found 2');
}

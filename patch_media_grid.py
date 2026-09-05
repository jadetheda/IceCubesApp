import re

with open('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', 'r') as f:
    text = f.read()

text = text.replace(
    '''    List {
      StatusesListView(
        fetcher: fetcher,
        client: client,
        routerPath: routerPath,
        isRemote: isRemote,
        isForceGalleryMode: true
      )
      .listRowInsets(EdgeInsets())
      .listRowBackground(theme.primaryBackgroundColor)
    }
    .listStyle(.plain)''',
    '''    ScrollView {
      LazyVStack(spacing: 0) {
        StatusesListView(
          fetcher: fetcher,
          client: client,
          routerPath: routerPath,
          isRemote: isRemote,
          isForceGalleryMode: true
        )
      }
    }'''
)

with open('Packages/Account/Sources/Account/Detail/MediaGrid/AccountDetailMediaGridView.swift', 'w') as f:
    f.write(text)

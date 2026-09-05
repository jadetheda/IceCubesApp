import re

with open('Packages/StatusKit/Sources/StatusKit/List/StatusesListView.swift', 'r') as f:
    slv = f.read()

# Add Environment for horizontalSizeClass
if 'horizontalSizeClass' not in slv:
    slv = slv.replace('@Environment(Theme.self) private var theme', 
                      '@Environment(Theme.self) private var theme\n  @Environment(\\.horizontalSizeClass) private var horizontalSizeClass')

# Modify body to check for isGalleryMode
body_start = slv.find('public var body: some View {\n')
if body_start != -1:
    body_content_start = body_start + len('public var body: some View {\n')
    
    # We will replace the entire body with an if/else, and move the existing body into listBody
    # Find the end of body by matching braces.
    brace_count = 1
    i = body_content_start
    while i < len(slv) and brace_count > 0:
        if slv[i] == '{':
            brace_count += 1
        elif slv[i] == '}':
            brace_count -= 1
        i += 1
    
    body_content = slv[body_content_start:i-1]
    
    new_body = """    if TimelineContentFilter.shared.isGalleryMode {
      galleryBody
    } else {
      listBody
    }
  }

  @ViewBuilder
  private var listBody: some View {
""" + body_content + "\n  }\n"
    
    slv = slv[:body_content_start] + new_body + slv[i:]

# Now we need to append the gallery methods at the end of the struct.
# We'll extract them from GalleryStatusesListView.swift.
with open('Packages/StatusKit/Sources/StatusKit/List/GalleryStatusesListView.swift', 'r') as f:
    glv = f.read()

# Extract from 'private struct GalleryNode' all the way down to 'private func makeGridChunk'
# The easiest way is to find 'private struct GalleryNode' and find the end of 'makeGridChunk'

node_idx = glv.find('private struct GalleryNode')
chunk_idx = glv.find('private func makeGridChunk')

# find the end of makeGridChunk by brace counting
brace_count = 0
i = chunk_idx
found_open = False
while i < len(glv):
    if glv[i] == '{':
        brace_count += 1
        found_open = True
    elif glv[i] == '}':
        brace_count -= 1
    i += 1
    if found_open and brace_count == 0:
        break

gallery_methods = glv[node_idx:i]

# Extract the gallery body switch statement from GalleryStatusesListView.swift
glv_body_start = glv.find('switch statusesState {')
glv_body_end = glv.find('  private struct GalleryNode')

glv_body = glv[glv_body_start:glv_body_end].strip()
# replace 'statusesState' with 'fetcher.statusesState', 'fetchNextPage' with 'fetcher.fetchNextPage', etc.
glv_body = glv_body.replace('statusesState', 'fetcher.statusesState')
glv_body = glv_body.replace('fetchNewestStatuses()', 'fetcher.fetchNewestStatuses(pullToRefresh: false)')
glv_body = glv_body.replace('fetchNextPage()', 'fetcher.fetchNextPage()')

# In makeGrid: 'if let loadGap = loadGap' -> 'if let loadGap = fetcher as? GapLoadingFetcher'
gallery_methods = gallery_methods.replace('if let loadGap = loadGap {', 'if let loadGap = fetcher as? GapLoadingFetcher {')
gallery_methods = gallery_methods.replace('await loadGap(gap)', 'await loadGap.loadGap(gap: gap)')
gallery_methods = gallery_methods.replace('fetchNextPage()', 'fetcher.fetchNextPage()')

# In makeGridChunk: 'statusDidAppear?(mediaStatus.status)' -> 'fetcher.statusDidAppear(status: mediaStatus.status)'
gallery_methods = gallery_methods.replace('statusDidAppear?(mediaStatus.status)', 'fetcher.statusDidAppear(status: mediaStatus.status)')
gallery_methods = gallery_methods.replace('statusDidDisappear?(mediaStatus.status)', 'fetcher.statusDidDisappear(status: mediaStatus.status)')

gallery_methods = gallery_methods.replace('makeNextPageRow(nextPageState: nextPageState)', 'makeGalleryNextPageRow(nextPageState: nextPageState)')
gallery_methods = gallery_methods.replace('private func makeNextPageRow(nextPageState: StatusesState.PagingState)', 'private func makeGalleryNextPageRow(nextPageState: StatusesState.PagingState)')

full_gallery_code = """  @ViewBuilder
  private var galleryBody: some View {
""" + "\n".join("    " + line for line in glv_body.split('\n')) + """
  }

""" + "\n".join("  " + line for line in gallery_methods.split('\n'))

# Insert before the last brace of slv
last_brace = slv.rfind('}')
slv = slv[:last_brace] + full_gallery_code + "\n}\n"

with open('Packages/StatusKit/Sources/StatusKit/List/StatusesListView.swift', 'w') as f:
    f.write(slv)

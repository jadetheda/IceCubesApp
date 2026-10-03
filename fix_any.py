with open("Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift", "r") as f:
    content = f.read()

target1 = """  private var shouldShowFilterWarningBanner: Bool {
    showFilterWarning && (contentFilter.hidePostsWithMedia || contentFilter.hidePostsWithoutMedia)
  }"""
replacement1 = """  private var shouldShowFilterWarningBanner: Bool {
    if !showFilterWarning { return false }
    if contentFilter.hidePostsWithMedia { return true }
    if contentFilter.hidePostsWithoutMedia { return true }
    return false
  }"""

target2 = """  private func filteredStatuses(_ statuses: [Status]) -> [Status] {
    return statuses.filter { status in
      if contentFilter.hidePostsWithMedia {
        if !status.mediaAttachments.isEmpty || status.reblog?.mediaAttachments.isEmpty == false { return false }
      }
      if contentFilter.hidePostsWithoutMedia {
        if status.mediaAttachments.isEmpty && (status.reblog?.mediaAttachments.isEmpty ?? true) { return false }
      }
      return true
    }
  }"""
replacement2 = """  private func filteredStatuses(_ statuses: [Status]) -> [Status] {
    return statuses.filter { status in
      if contentFilter.hidePostsWithMedia {
        if !status.mediaAttachments.isEmpty {
          return false
        }
        if status.reblog?.mediaAttachments.isEmpty == false {
          return false
        }
      }
      if contentFilter.hidePostsWithoutMedia {
        if status.mediaAttachments.isEmpty {
          let reblogEmpty = status.reblog?.mediaAttachments.isEmpty ?? true
          if reblogEmpty {
            return false
          }
        }
      }
      return true
    }
  }"""

if target1 in content:
    content = content.replace(target1, replacement1)
    print("Fixed target1")
if target2 in content:
    content = content.replace(target2, replacement2)
    print("Fixed target2")

with open("Packages/Account/Sources/Account/Detail/Tabs/Base/AnyStatusesListView.swift", "w") as f:
    f.write(content)

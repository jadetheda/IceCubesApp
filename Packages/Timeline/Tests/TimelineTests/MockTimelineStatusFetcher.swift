import Models
import NetworkClient

@testable import Timeline

actor MockTimelineStatusFetcher: TimelineStatusFetching {
  private let firstPage: [Status]
  private let nextPages: [[Status]]
  private var nextPageCalls: Int = 0

  init(firstPage: [Status], nextPages: [[Status]]) {
    self.firstPage = firstPage
    self.nextPages = nextPages
  }

  func fetchFirstPage(client: FediverseClient?, timeline: TimelineFilter) async throws -> [Status] {
    firstPage
  }

  func fetchNewPages(
    client: FediverseClient?,
    timeline: TimelineFilter,
    minId: String,
    maxPages: Int
  ) async throws -> [Status] {
    []
  }

  func fetchNextPage(
    client: FediverseClient?,
    timeline: TimelineFilter,
    lastId: String,
    offset: Int
  ) async throws -> [Status] {
    defer { nextPageCalls += 1 }
    guard nextPageCalls < nextPages.count else { return [] }
    return nextPages[nextPageCalls]
  }

  func nextPageCallCount() -> Int {
    nextPageCalls
  }
}

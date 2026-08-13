const fs = require('fs');
let content = fs.readFileSync('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', 'utf8');

const replacement = `      List {
        ScrollToView()
          .frame(height: pinnedFilters.isEmpty ? .layoutPadding : 0.5)
          .onAppear {
            viewModel.scrollToTopVisible = true
          }
          .onDisappear {
            viewModel.scrollToTopVisible = false
          }
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        
        TimelineTagGroupheaderView(group: $selectedTagGroup, timeline: $timeline)
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          
        TimelineTagHeaderView(tag: $viewModel.tag)
          .listRowBackground(theme.primaryBackgroundColor)
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          
        if TimelineContentFilter.shared.isGalleryMode {
          switch viewModel.timeline {
          case .remoteLocal:
            GalleryStatusesListView(
              fetcher: viewModel,
              client: client,
              routerPath: routerPath,
              isRemote: true,
              filterContext: timeline.filterContext)
          default:
            GalleryStatusesListView(
              fetcher: viewModel,
              client: client,
              routerPath: routerPath,
              filterContext: timeline.filterContext)
              .environment(\\.isHomeTimeline, timeline == .home)
          }
        } else {
          switch viewModel.timeline {
          case .remoteLocal:
            StatusesListView(
              fetcher: viewModel,
              client: client,
              routerPath: routerPath,
              isRemote: true,
              filterContext: timeline.filterContext)
          default:
            StatusesListView(
              fetcher: viewModel,
              client: client,
              routerPath: routerPath,
              filterContext: timeline.filterContext)
              .environment(\\.isHomeTimeline, timeline == .home)
          }
        }
      }`;

const startIndex = content.indexOf('      Group {');
const endIndex = content.indexOf('      .id(client.id)', startIndex);

if (startIndex !== -1 && endIndex !== -1) {
    const search = content.substring(startIndex, endIndex);
    content = content.replace(search, replacement + '\n');
    fs.writeFileSync('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', content);
    console.log('Success');
} else {
    console.log('Not found');
}

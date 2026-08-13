const fs = require('fs');

// Patch 1: TimelineListView.swift
let contentTimeline = fs.readFileSync('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', 'utf8');

const searchTimeline = `      List {
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

const replaceTimeline = `      Group {
        if TimelineContentFilter.shared.isGalleryMode {
          ScrollView {
            LazyVStack(spacing: 0) {
              ScrollToView()
                .frame(height: pinnedFilters.isEmpty ? .layoutPadding : 0.5)
                .onAppear {
                  viewModel.scrollToTopVisible = true
                }
                .onDisappear {
                  viewModel.scrollToTopVisible = false
                }
              TimelineTagGroupheaderView(group: $selectedTagGroup, timeline: $timeline)
              TimelineTagHeaderView(tag: $viewModel.tag)
              
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
            }
          }
        } else {
          List {
            ScrollToView()
              .frame(height: pinnedFilters.isEmpty ? .layoutPadding : 0.5)
              .onAppear {
                viewModel.scrollToTopVisible = true
              }
              .onDisappear {
                viewModel.scrollToTopVisible = false
              }
            
            TimelineTagGroupheaderView(group: $selectedTagGroup, timeline: $timeline)
            TimelineTagHeaderView(tag: $viewModel.tag)
            
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
        }
      }`;

if (contentTimeline.includes(searchTimeline)) {
    fs.writeFileSync('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', contentTimeline.replace(searchTimeline, replaceTimeline));
    console.log('Reverted TimelineListView');
} else {
    console.log('Could not find search block in TimelineListView');
}


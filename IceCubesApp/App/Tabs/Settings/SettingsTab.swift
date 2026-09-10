import Account
import AppAccount
import DesignSystem
import Env
import Foundation
import Models
import NetworkClient
import Nuke
import SwiftData
import SwiftUI
import Timeline
import UniformTypeIdentifiers

@MainActor
struct SettingsTabs: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @Environment(PushNotificationsService.self) private var pushNotifications
  @Environment(UserPreferences.self) private var preferences
  @Environment(FediverseClient.self) private var client
  @Environment(CurrentInstance.self) private var currentInstance
  @Environment(AppAccountsManager.self) private var appAccountsManager
  @Environment(Theme.self) private var theme
  @Environment(\.modelContext) private var context

  @State private var routerPath = RouterPath()
  @State private var addAccountSheetPresented = false
  @State private var isEditingAccount = false
  @State private var cachedRemoved = false
  @State private var timelineCache = TimelineCache()
  @State private var isExportingSettings = false
  @State private var isImportingSettings = false
  @State private var settingsDocument: IceCubesDocument?

  let isModal: Bool

  @State private var startingPoint: SettingsStartingPoint? = nil

  var body: some View {
    NavigationStack(path: $routerPath.path) {
      Form {
        appSection
        accountsSection
        generalSection
        socialKeyboardSection
        streamHomeTimelineSection
        timelineFetchSection
        otherSections
        cacheSection
        settingsBackupSection
      }
      .scrollContentBackground(.hidden)
      #if !os(visionOS)
        .background(theme.secondaryBackgroundColor)
      #endif
      .navigationTitle(Text("settings.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if isModal {
          ToolbarItem {
            Button {
              dismiss()
            } label: {
              Text("action.done").bold()
            }
          }
        }
        if UIDevice.current.userInterfaceIdiom == .pad, !preferences.showiPadSecondaryColumn,
          !isModal
        {
          SecondaryColumnToolbarItem()
        }
      }
      .withAppRouter()
      .withSheetDestinations(
        sheetDestinations: $routerPath.presentedSheet,
        routerPath: routerPath
      )
      .fileExporter(
        isPresented: $isExportingSettings,
        document: settingsDocument,
        contentType: .json,
        defaultFilename: "IceCubes_Settings"
      ) { result in
        if case .failure(let error) = result {
          print("Settings export failed: \(error.localizedDescription)")
        }
      }
      .fileImporter(isPresented: $isImportingSettings, allowedContentTypes: [.json]) { result in
        guard case .success(let url) = result else {
          if case .failure(let error) = result {
            print("Settings import failed: \(error.localizedDescription)")
          }
          return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
          if accessed {
            url.stopAccessingSecurityScopedResource()
          }
        }

        do {
          let data = try Data(contentsOf: url)
          let export = try JSONDecoder().decode(AppExport.self, from: data)
          applyExport(export)
        } catch {
          print("Settings import failed: \(error.localizedDescription)")
        }
      }
      .onAppear {
        startingPoint = RouterPath.settingsStartingPoint
        RouterPath.settingsStartingPoint = nil
      }
      .navigationDestination(item: $startingPoint) { targetView in
        switch targetView {
        case .display:
          DisplaySettingsView()
        case .haptic:
          HapticSettingsView()
        case .remoteTimelines:
          RemoteTimelinesSettingView()
        case .tagGroups:
          TagsGroupSettingView()
        case .recentTags:
          RecenTagsSettingView()
        case .content:
          ContentSettingsView()
        case .swipeActions:
          SwipeActionsSettingsView()
        case .tabAndSidebarEntries:
          EmptyView()
        case .translation:
          TranslationSettingsView()
        }
      }
    }
    .onAppear {
      routerPath.client = client
    }
    .task {
      if appAccountsManager.currentAccount.oauthToken != nil {
        await currentInstance.fetchCurrentInstance()
      }
    }
    .withSafariRouter()
    .environment(routerPath)
  }

  private var accountsSection: some View {
    Section("settings.section.accounts") {
      ForEach(appAccountsManager.availableAccounts) { account in
        HStack {
          if isEditingAccount {
            Button {
              Task {
                await logoutAccount(account: account)
              }
            } label: {
              Image(systemName: "trash")
                .renderingMode(.template)
                .tint(.red)
            }
          }
          AppAccountView(viewModel: .init(appAccount: account), isParentPresented: .constant(false))
        }
      }
      .onDelete { indexSet in
        if let index = indexSet.first {
          let account = appAccountsManager.availableAccounts[index]
          Task {
            await logoutAccount(account: account)
          }
        }
      }
      addAccountButton
      if !appAccountsManager.availableAccounts.isEmpty {
        editAccountButton
      }
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private func logoutAccount(account: AppAccount) async {
    if let token = account.oauthToken,
      let sub = pushNotifications.subscriptions.first(where: { $0.account.token == token })
    {
      let client = FediverseClient(server: account.server, oauthToken: token)
      await timelineCache.clearCache(for: client.id)
      await sub.deleteSubscription()
      appAccountsManager.delete(account: account)
      Telemetry.signal("account.removed")
    }
  }

  @ViewBuilder
  private var generalSection: some View {
    Section("settings.section.general") {
      if let instanceData = currentInstance.instance {
        NavigationLink(value: RouterDestination.instanceInfo(instance: instanceData)) {
          Label("settings.general.instance", systemImage: "server.rack")
        }
      }
      NavigationLink(destination: DisplaySettingsView()) {
        Label("settings.general.display", systemImage: "paintpalette")
      }
      if HapticManager.shared.supportsHaptics {
        NavigationLink(destination: HapticSettingsView()) {
          Label("settings.general.haptic", systemImage: "waveform.path")
        }
      }
      NavigationLink(destination: RemoteTimelinesSettingView()) {
        Label("settings.general.remote-timelines", systemImage: "dot.radiowaves.right")
      }
      NavigationLink(destination: TagsGroupSettingView()) {
        Label("timeline.filter.tag-groups", systemImage: "number")
      }
      NavigationLink(destination: RecenTagsSettingView()) {
        Label("settings.general.recent-tags", systemImage: "clock")
      }
      NavigationLink(destination: ContentSettingsView()) {
        Label("settings.general.content", systemImage: "rectangle.stack")
      }
      NavigationLink(destination: SwipeActionsSettingsView()) {
        Label("settings.general.swipeactions", systemImage: "hand.draw")
      }
      if UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact {
        NavigationLink(destination: TabbarEntriesSettingsView()) {
          Label("settings.general.tabbarEntries", systemImage: "platter.filled.bottom.iphone")
        }
      }
      NavigationLink(destination: TranslationSettingsView()) {
        Label("settings.general.translate", systemImage: "captions.bubble")
      }
      #if !targetEnvironment(macCatalyst)
        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
          Label("settings.system", systemImage: "gear")
        }
        .tint(theme.labelColor)
      #endif
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  @ViewBuilder
  private var otherSections: some View {
    @Bindable var preferences = preferences
    Section {
      #if !targetEnvironment(macCatalyst)
        Picker(selection: $preferences.preferredBrowser) {
          ForEach(PreferredBrowser.allCases, id: \.rawValue) { browser in
            switch browser {
            case .inAppSafari:
              Text("settings.general.browser.in-app").tag(browser)
            case .safari:
              Text("settings.general.browser.system").tag(browser)
            }
          }
        } label: {
          Label("settings.general.browser", systemImage: "network")
        }
        Toggle(isOn: $preferences.inAppBrowserReaderView) {
          Label("settings.general.browser.in-app.readerview", systemImage: "doc.plaintext")
        }
        .disabled(preferences.preferredBrowser != PreferredBrowser.inAppSafari)
      #endif
      Toggle(isOn: $preferences.soundEffectEnabled) {
        Label("settings.other.sound-effect", systemImage: "hifispeaker")
      }
    } header: {
      Text("settings.section.other")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var socialKeyboardSection: some View {
    @Bindable var preferences = preferences
    return Section {
      Toggle(isOn: $preferences.isSocialKeyboardEnabled) {
        Label("settings.other.social-keyboard", systemImage: "keyboard")
      }
    } footer: {
      Text("Adds @ and # keys directly on the keyboard for faster mentions and hashtags.")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var streamHomeTimelineSection: some View {
    @Bindable var preferences = preferences
    return Section {
      Toggle(isOn: $preferences.streamHomeTimeline) {
        Label("Stream home timeline", systemImage: "antenna.radiowaves.left.and.right")
          .symbolVariant(preferences.streamHomeTimeline ? .none : .slash)
      }
    } footer: {
      Text("Keeps your home timeline up to date in real time using streaming when available. Disable in case of performance issues.")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var timelineFetchSection: some View {
    @Bindable var preferences = preferences
    return Section {
      Toggle(isOn: $preferences.fullTimelineFetch) {
        Label("Full timeline fetch", systemImage: "arrow.triangle.2.circlepath")
          .symbolVariant(preferences.fullTimelineFetch ? .none : .slash)
      }
    } footer: {
      Text("Fetches all new timeline posts (up to 800) instead of only the latest 40 + manually loading the gap.")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var appSection: some View {
    Section {
      #if !targetEnvironment(macCatalyst) && !os(visionOS)
        NavigationLink(destination: IconSelectorView()) {
          Label {
            Text("settings.app.icon")
          } icon: {
            let icon = IconSelectorView.Icon(
              string: UIApplication.shared.alternateIconName ?? "AppIcon")
            if let image: UIImage = .init(named: icon.previewImageName) {
              Image(uiImage: image)
                .resizable()
                .frame(width: 25, height: 25)
                .cornerRadius(4)
            } else {
              EmptyView()
            }
          }
        }
      #endif

      Link(destination: URL(string: "https://github.com/Dimillian/IceCubesApp")!) {
        Label("settings.app.source", systemImage: "link")
      }
      .accessibilityRemoveTraits(.isButton)
      .tint(theme.labelColor)

      NavigationLink(destination: SupportAppView()) {
        Label("settings.app.support", systemImage: "wand.and.stars")
      }

      if let reviewURL = URL(
        string: "https://apps.apple.com/app/id\(AppInfo.appStoreAppId)?action=write-review")
      {
        Link(destination: reviewURL) {
          Label("settings.rate", systemImage: "link")
        }
        .accessibilityRemoveTraits(.isButton)
        .tint(theme.labelColor)
      }

      NavigationLink {
        AboutView()
      } label: {
        Label("settings.app.about", systemImage: "info.circle")
      }

      #if !targetEnvironment(macCatalyst)
        NavigationLink {
          WishlistView()
        } label: {
          Label("settings.wishlist.title", systemImage: "list.bullet.rectangle.portrait")
        }
      #endif

    } header: {
      Text("settings.section.app")
    } footer: {
      if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        Text("settings.section.app.footer \(appVersion)").frame(
          maxWidth: .infinity, alignment: .center)
      }
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var addAccountButton: some View {
    Button {
      addAccountSheetPresented.toggle()
    } label: {
      Label("settings.account.add", systemImage: "person.badge.plus")
    }
    .sheet(isPresented: $addAccountSheetPresented) {
      AddAccountView()
    }
  }

  private var editAccountButton: some View {
    Button(role: .destructive) {
      withAnimation {
        isEditingAccount.toggle()
      }
    } label: {
      if isEditingAccount {
        Label("action.done", systemImage: "person.badge.minus")
          .foregroundStyle(.red)
      } else {
        Label("account.action.logout", systemImage: "person.badge.minus")
          .foregroundStyle(.red)
      }
    }
  }

  private var settingsBackupSection: some View {
    Section {
      Button("settings.export.title") {
        prepareExport()
      }
      Button("settings.import.title") {
        isImportingSettings = true
      }
    } header: {
      Text("settings.experimental.header")
    } footer: {
      Text("Export preferences, tag groups, and remote timeline configurations to a JSON file.")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private func prepareExport() {
    var values: [String: AnyCodable] = [:]
    let defaults = UserDefaults.standard.dictionaryRepresentation()
      .merging(UserPreferences.sharedDefault?.dictionaryRepresentation() ?? [:]) { first, _ in first }
    for (key, value) in defaults {
      guard !key.hasPrefix("Apple"), !key.hasPrefix("NS"), !key.hasPrefix("WebKit"),
        !key.hasPrefix("UI"), !key.hasPrefix("Metal"), !key.hasPrefix("com.apple"),
        let codableValue = AnyCodable.parse(value)
      else { continue }
      values[key] = codableValue
    }
    let tagGroups = try? context.fetch(FetchDescriptor<TagGroup>()).map {
      ExportedTagGroup(title: $0.title, symbolName: $0.symbolName, tags: $0.tags, creationDate: $0.creationDate)
    }
    let localTimelines = try? context.fetch(FetchDescriptor<LocalTimeline>()).map {
      ExportedLocalTimeline(instance: $0.instance, creationDate: $0.creationDate)
    }
    settingsDocument = IceCubesDocument(
      export: AppExport(userDefaults: values, tagGroups: tagGroups, localTimelines: localTimelines))
    isExportingSettings = true
  }

  private func applyExport(_ export: AppExport) {
    for (key, value) in export.userDefaults {
      UserDefaults.standard.set(value.value, forKey: key)
      UserPreferences.sharedDefault?.set(value.value, forKey: key)
    }
    if let tagGroups = export.tagGroups {
      for tagGroup in (try? context.fetch(FetchDescriptor<TagGroup>())) ?? [] {
        context.delete(tagGroup)
      }
      for tagGroup in tagGroups {
        let model = TagGroup(title: tagGroup.title, symbolName: tagGroup.symbolName, tags: tagGroup.tags)
        model.creationDate = tagGroup.creationDate
        context.insert(model)
      }
    }
    if let localTimelines = export.localTimelines {
      for timeline in (try? context.fetch(FetchDescriptor<LocalTimeline>())) ?? [] {
        context.delete(timeline)
      }
      for timeline in localTimelines {
        let model = LocalTimeline(instance: timeline.instance)
        model.creationDate = timeline.creationDate
        context.insert(model)
      }
    }
    do {
      try context.save()
    } catch {
      print("Settings import save failed: \(error.localizedDescription)")
    }
  }

  nonisolated struct AppExport: Codable, Sendable {
    let userDefaults: [String: AnyCodable]
    let tagGroups: [ExportedTagGroup]?
    let localTimelines: [ExportedLocalTimeline]?
  }

  nonisolated struct ExportedTagGroup: Codable, Sendable {
    let title: String
    let symbolName: String
    let tags: [String]
    let creationDate: Date
  }

  nonisolated struct ExportedLocalTimeline: Codable, Sendable {
    let instance: String
    let creationDate: Date
  }

  nonisolated enum AnyCodable: Codable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case data(Data)
    case date(Date)
    case array([AnyCodable])
    case dict([String: AnyCodable])

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(Bool.self) { self = .boolean(value) }
      else if let value = try? container.decode(Int.self) { self = .integer(value) }
      else if let value = try? container.decode(Double.self) { self = .double(value) }
      else if let value = try? container.decode(String.self) { self = .string(value) }
      else if let value = try? container.decode(Data.self) { self = .data(value) }
      else if let value = try? container.decode(Date.self) { self = .date(value) }
      else if let value = try? container.decode([AnyCodable].self) { self = .array(value) }
      else if let value = try? container.decode([String: AnyCodable].self) { self = .dict(value) }
      else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid settings value") }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .string(let value): try container.encode(value)
      case .integer(let value): try container.encode(value)
      case .double(let value): try container.encode(value)
      case .boolean(let value): try container.encode(value)
      case .data(let value): try container.encode(value)
      case .date(let value): try container.encode(value)
      case .array(let value): try container.encode(value)
      case .dict(let value): try container.encode(value)
      }
    }

    var value: Any {
      switch self {
      case .string(let value): value
      case .integer(let value): value
      case .double(let value): value
      case .boolean(let value): value
      case .data(let value): value
      case .date(let value): value
      case .array(let value): value.map(\.value)
      case .dict(let value): value.mapValues(\.value)
      }
    }

    static func parse(_ value: Any) -> AnyCodable? {
      if let value = value as? String { return .string(value) }
      if let value = value as? Bool { return .boolean(value) }
      if let value = value as? Int { return .integer(value) }
      if let value = value as? Double { return .double(value) }
      if let value = value as? Data { return .data(value) }
      if let value = value as? Date { return .date(value) }
      if let value = value as? [Any] { return .array(value.compactMap(parse)) }
      if let value = value as? [String: Any] { return .dict(value.compactMapValues(parse)) }
      return nil
    }
  }

  nonisolated struct IceCubesDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.json] }
    var export: AppExport

    init(export: AppExport) {
      self.export = export
    }

    init(configuration: ReadConfiguration) throws {
      guard let data = configuration.file.regularFileContents else {
        throw CocoaError(.fileReadCorruptFile)
      }
      export = try JSONDecoder().decode(AppExport.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
      .init(regularFileWithContents: try JSONEncoder().encode(export))
    }
  }

  private var cacheSection: some View {
    Section {
      if cachedRemoved {
        Text("action.done")
          .transition(.move(edge: .leading))
      } else {
        Button("settings.cache-media.clear", role: .destructive) {
          ImagePipeline.shared.cache.removeAll()
          withAnimation {
            cachedRemoved = true
          }
        }
      }
    } header: {
      Text("settings.section.cache")
    } footer: {
      Text("Remove all cached images and videos")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }
}

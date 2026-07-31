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
  @Environment(MastodonClient.self) private var client
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
  @State private var settingsDocument: IceCubesDocument? = nil

  let isModal: Bool

  @State private var startingPoint: SettingsStartingPoint? = nil

  var body: some View {
    NavigationStack(path: $routerPath.path) {
      Form {
        appSection
        accountsSection
        experimentalSection
        generalSection
        socialKeyboardSection
        streamHomeTimelineSection
        timelineFetchSection
        otherSections
        cacheSection
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
    .fileExporter(isPresented: $isExportingSettings, document: settingsDocument, contentType: .json, defaultFilename: "IceCubes_Settings") { result in
      switch result {
      case .success(let url):
        print("Saved to \(url)")
      case .failure(let error):
        print(error.localizedDescription)
      }
    }
    .fileImporter(isPresented: $isImportingSettings, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let url):
        do {
          _ = url.startAccessingSecurityScopedResource()
          let data = try Data(contentsOf: url)
          let export = try JSONDecoder().decode(AppExport.self, from: data)
          url.stopAccessingSecurityScopedResource()
          applyExport(export)
        } catch {
          print(error)
        }
      case .failure(let error):
        print(error.localizedDescription)
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
      let client = MastodonClient(server: account.server, oauthToken: token)
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
      Text("settings.other.social-keyboard.footer")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var streamHomeTimelineSection: some View {
    @Bindable var preferences = preferences
    return Section {
      Toggle(isOn: $preferences.streamHomeTimeline) {
        Label("settings.experimental.stream-home", systemImage: "antenna.radiowaves.left.and.right")
          .symbolVariant(preferences.streamHomeTimeline ? .none : .slash)
      }
    } footer: {
      Text("settings.experimental.stream-home.footer")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  private var timelineFetchSection: some View {
    @Bindable var preferences = preferences
    return Section {
      Toggle(isOn: $preferences.fullTimelineFetch) {
        Label("settings.experimental.full-timeline-fetch", systemImage: "arrow.triangle.2.circlepath")
          .symbolVariant(preferences.fullTimelineFetch ? .none : .slash)
      }
    } footer: {
      Text("settings.experimental.full-timeline-fetch.footer")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }
  private var experimentalSection: some View {
    Section {
      Button("settings.export.title") {
        prepareExport()
      }
      Button("settings.import.title") {
        isImportingSettings = true
      }
    } header: {
      Text("settings.experimental.header")
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

      NavigationLink {
        WishlistView()
      } label: {
        Label("settings.wishlist.title", systemImage: "list.bullet.rectangle.portrait")
      }

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

  private var cacheSection: some View {
    @Bindable var preferences = preferences
    return Section {
      Toggle(isOn: $preferences.cacheServerEmotes) {
        Text("settings.other.cache-server-emotes")
      }
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
      Text("settings.cache.footer")
    }
    #if !os(visionOS)
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  /// Extracts the current UserDefaults state and SwiftData models into an AppExport payload.
  private func prepareExport() {
    var appDefaults: [String: AnyCodable] = [:]
    
    let defaultsDict = UserDefaults.standard.dictionaryRepresentation()
    let sharedDict = UserPreferences.sharedDefault?.dictionaryRepresentation() ?? [:]
    
    // Filter standard Apple keys to prevent importing system/device-specific state
    for (key, value) in defaultsDict.merging(sharedDict, uniquingKeysWith: { a, _ in a }) {
      if key.starts(with: "Apple") || key.starts(with: "NS") || key.starts(with: "WebKit") || key.starts(with: "UI") || key.starts(with: "Metal") || key.starts(with: "com.apple") {
        continue
      }
      if let codableValue = AnyCodable.parse(value) {
        appDefaults[key] = codableValue
      }
    }
    
    // Fetch SwiftData configurations (TagGroups)
    let descriptor = FetchDescriptor<TagGroup>()
    let tags = try? context.fetch(descriptor).map { tag in
      ExportedTagGroup(title: tag.title, symbolName: tag.symbolName, tags: tag.tags, creationDate: tag.creationDate)
    }
    
    // Fetch SwiftData configurations (LocalTimelines)
    let ltDescriptor = FetchDescriptor<LocalTimeline>()
    let localTimelines = try? context.fetch(ltDescriptor).map { lt in
      ExportedLocalTimeline(instance: lt.instance, creationDate: lt.creationDate)
    }
    
    let export = AppExport(userDefaults: appDefaults, tagGroups: tags, localTimelines: localTimelines)
    settingsDocument = IceCubesDocument(export: export)
    isExportingSettings = true
  }

  /// Injects an AppExport payload directly into UserDefaults and SwiftData.
  private func applyExport(_ export: AppExport) {
    // 1. Restore UserDefaults keys
    for (key, anyCodable) in export.userDefaults {
      UserDefaults.standard.set(anyCodable.value, forKey: key)
      UserPreferences.sharedDefault?.set(anyCodable.value, forKey: key)
    }
    UserDefaults.standard.synchronize()
    UserPreferences.sharedDefault?.synchronize()
    
    // 2. Restore TagGroups in SwiftData (wiping existing)
    if let tags = export.tagGroups {
      let descriptor = FetchDescriptor<TagGroup>()
      if let existing = try? context.fetch(descriptor) {
        for tag in existing {
          context.delete(tag)
        }
      }
      for tag in tags {
        let newTag = TagGroup(title: tag.title, symbolName: tag.symbolName, tags: tag.tags)
        newTag.creationDate = tag.creationDate
        context.insert(newTag)
      }
    }
    
    // 3. Restore LocalTimelines in SwiftData (wiping existing)
    if let localTimelines = export.localTimelines {
      let descriptor = FetchDescriptor<LocalTimeline>()
      if let existing = try? context.fetch(descriptor) {
        for lt in existing {
          context.delete(lt)
        }
      }
      for lt in localTimelines {
        let newLt = LocalTimeline(instance: lt.instance)
        newLt.creationDate = lt.creationDate
        context.insert(newLt)
      }
    }
    
    try? context.save()
    
    // Let app reload preferences if needed. UI responds via @AppStorage listeners implicitly.
  }
}

/// Represents a complete snapshot of user preferences and saved instances.
public struct AppExport: Codable, Sendable {
  public let userDefaults: [String: AnyCodable]
  public let tagGroups: [ExportedTagGroup]?
  public let localTimelines: [ExportedLocalTimeline]?
  
  public init(userDefaults: [String: AnyCodable], tagGroups: [ExportedTagGroup]?, localTimelines: [ExportedLocalTimeline]?) {
    self.userDefaults = userDefaults
    self.tagGroups = tagGroups
    self.localTimelines = localTimelines
  }

  enum CodingKeys: String, CodingKey {
    case userDefaults, tagGroups, localTimelines
  }

  nonisolated public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.userDefaults = try container.decode([String: AnyCodable].self, forKey: .userDefaults)
    self.tagGroups = try container.decodeIfPresent([ExportedTagGroup].self, forKey: .tagGroups)
    self.localTimelines = try container.decodeIfPresent([ExportedLocalTimeline].self, forKey: .localTimelines)
  }

  nonisolated public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(userDefaults, forKey: .userDefaults)
    try container.encodeIfPresent(tagGroups, forKey: .tagGroups)
    try container.encodeIfPresent(localTimelines, forKey: .localTimelines)
  }
}

/// A Codable representation of the TagGroup model used for file export.
public struct ExportedTagGroup: Codable, Sendable {
  public let title: String
  public let symbolName: String
  public let tags: [String]
  public let creationDate: Date
}

/// A Codable representation of the LocalTimeline model used for file export.
public struct ExportedLocalTimeline: Codable, Sendable {
  public let instance: String
  public let creationDate: Date
}

/// A type-erased wrapper to handle encoding/decoding mixed-type UserDefaults dictionaries.
public enum AnyCodable: Codable, Sendable {
  case string(String)
  case integer(Int)
  case double(Double)
  case boolean(Bool)
  case data(Data)
  case date(Date)
  case array([AnyCodable])
  case dict([String: AnyCodable])
  
  nonisolated public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let x = try? container.decode(Bool.self) { self = .boolean(x) }
    else if let x = try? container.decode(Int.self) { self = .integer(x) }
    else if let x = try? container.decode(Double.self) { self = .double(x) }
    else if let x = try? container.decode(String.self) { self = .string(x) }
    else if let x = try? container.decode(Data.self) { self = .data(x) }
    else if let x = try? container.decode(Date.self) { self = .date(x) }
    else if let x = try? container.decode([AnyCodable].self) { self = .array(x) }
    else if let x = try? container.decode([String: AnyCodable].self) { self = .dict(x) }
    else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid AnyCodable value") }
  }
  
  nonisolated public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let x): try container.encode(x)
    case .integer(let x): try container.encode(x)
    case .double(let x): try container.encode(x)
    case .boolean(let x): try container.encode(x)
    case .data(let x): try container.encode(x)
    case .date(let x): try container.encode(x)
    case .array(let x): try container.encode(x)
    case .dict(let x): try container.encode(x)
    }
  }
  
  public var value: Any {
    switch self {
    case .string(let x): return x
    case .integer(let x): return x
    case .double(let x): return x
    case .boolean(let x): return x
    case .data(let x): return x
    case .date(let x): return x
    case .array(let x): return x.map { $0.value }
    case .dict(let x): return x.mapValues { $0.value }
    }
  }
  
  public static func parse(_ value: Any) -> AnyCodable? {
    if let x = value as? String { return .string(x) }
    if let x = value as? Bool { return .boolean(x) }
    if let x = value as? Int { return .integer(x) }
    if let x = value as? Double { return .double(x) }
    if let x = value as? Data { return .data(x) }
    if let x = value as? Date { return .date(x) }
    if let x = value as? [Any] { return .array(x.compactMap { parse($0) }) }
    if let x = value as? [String: Any] { return .dict(x.compactMapValues { parse($0) }) }
    return nil
  }
}

public struct IceCubesDocument: FileDocument, Sendable {
  public static var readableContentTypes: [UTType] { [.json] }
  public var export: AppExport

  public init(export: AppExport) {
    self.export = export
  }

  nonisolated public init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    let decoded = try JSONDecoder().decode(AppExport.self, from: data)
    // we must initialize self.export in a nonisolated way, which should be fine for a struct.
    // wait, FileDocument init is mutating if it's a struct!
    self.export = decoded
  }

  nonisolated public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let data = try JSONEncoder().encode(export)
    return .init(regularFileWithContents: data)
  }
}

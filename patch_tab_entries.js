const fs = require('fs');

let settingsCode = fs.readFileSync('IceCubesApp/App/Tabs/Settings/TabbarEntriesSettingsView.swift', 'utf8');

if (!settingsCode.includes('import AppAccount')) {
    settingsCode = settingsCode.replace('import Env\n', 'import Env\nimport AppAccount\n');
}

settingsCode = settingsCode.replace(/ForEach\(AppTab\.allCases\.filter \{ tab in\n\s*if tab == \.links \{ return appAccountsManager\.currentClient\.capabilities\.supportsTrendingLinks \}\n\s*if tab == \.metrics \{ return appAccountsManager\.currentClient\.capabilities\.supportsAccountMetrics \}\n\s*if tab == \.followedTags \{ return appAccountsManager\.currentClient\.capabilities\.supportsFollowedTags \}\n\s*if tab == \.lists \{ return !appAccountsManager\.currentClient\.isPixelfed \}\n\s*return true\n\s*\}\)/g, 'ForEach(availableTabs)');

settingsCode = settingsCode.replace(/var body: some View \{/, `private var availableTabs: [AppTab] {
    AppTab.allCases.filter { tab in
      if tab == .links { return appAccountsManager.currentClient.capabilities.supportsTrendingLinks }
      if tab == .metrics { return appAccountsManager.currentClient.capabilities.supportsAccountMetrics }
      if tab == .followedTags { return appAccountsManager.currentClient.capabilities.supportsFollowedTags }
      if tab == .lists { return !appAccountsManager.currentClient.isPixelfed }
      return true
    }
  }
  
  var body: some View {`);

fs.writeFileSync('IceCubesApp/App/Tabs/Settings/TabbarEntriesSettingsView.swift', settingsCode);

let appViewCode = fs.readFileSync('IceCubesApp/App/Main/AppView.swift', 'utf8');

appViewCode = appViewCode.replace(/ForEach\(section\.tabs\.filter \{ tab in\n\s*if tab == \.links \{ return appAccountsManager\.currentClient\.capabilities\.supportsTrendingLinks \}\n\s*if tab == \.metrics \{ return appAccountsManager\.currentClient\.capabilities\.supportsAccountMetrics \}\n\s*if tab == \.followedTags \{ return appAccountsManager\.currentClient\.capabilities\.supportsFollowedTags \}\n\s*if tab == \.lists \{ return !appAccountsManager\.currentClient\.isPixelfed \}\n\s*return true\n\s*\}\)/g, 'ForEach(availableTabs(for: section.tabs))');

appViewCode = appViewCode.replace(/var body: some View \{/, `private func availableTabs(for tabs: [AppTab]) -> [AppTab] {
    tabs.filter { tab in
      if tab == .links { return appAccountsManager.currentClient.capabilities.supportsTrendingLinks }
      if tab == .metrics { return appAccountsManager.currentClient.capabilities.supportsAccountMetrics }
      if tab == .followedTags { return appAccountsManager.currentClient.capabilities.supportsFollowedTags }
      if tab == .lists { return !appAccountsManager.currentClient.isPixelfed }
      return true
    }
  }
  
  var body: some View {`);

fs.writeFileSync('IceCubesApp/App/Main/AppView.swift', appViewCode);

console.log('Patched views to fix compiler timeouts');

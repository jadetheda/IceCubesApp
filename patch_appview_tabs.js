const fs = require('fs');
let code = fs.readFileSync('IceCubesApp/App/Main/AppView.swift', 'utf8');

code = code.replace(
    /ForEach\(section\.tabs\.filter \{ tab in\n\s*tab != \.links \|\| appAccountsManager\.currentClient\.capabilities\.supportsTrendingLinks\n\s*\}\) \{ tab in/g,
    `ForEach(section.tabs.filter { tab in
              if tab == .links { return appAccountsManager.currentClient.capabilities.supportsTrendingLinks }
              if tab == .metrics { return appAccountsManager.currentClient.capabilities.supportsAccountMetrics }
              if tab == .followedTags { return appAccountsManager.currentClient.capabilities.supportsFollowedTags }
              if tab == .lists { return !appAccountsManager.currentClient.isPixelfed }
              return true
            }) { tab in`
);

fs.writeFileSync('IceCubesApp/App/Main/AppView.swift', code);
console.log('Patched AppView tabs');

import re

with open('IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift', 'r') as f:
    text = f.read()

text = re.sub(r'          Toggle\("Show Boosts button on profiles", isOn: \$userPreferences\.iceShrimpShowBoostsButton\)\n', '', text)
text = re.sub(r'          Toggle\("settings\.content\.iceshrimp\.never-load-video", isOn: \$userPreferences\.neverLoadVideo\)\n', '', text)
text = re.sub(r'          Toggle\(isOn: \$userPreferences\.tagGroupsClientSideMergeEnabled\) \{\n            Label\("settings\.content\.iceshrimp\.alternative-tag-fetching", systemImage: "tag"\)\n          \}\n', '', text)

with open('IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift', 'w') as f:
    f.write(text)


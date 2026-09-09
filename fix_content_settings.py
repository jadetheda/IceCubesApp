import re

with open('IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift', 'r') as f:
    text = f.read()

# Remove the Toggle for useIceShrimpWorkarounds and the `if` block wrapper
text = re.sub(r'        // Toggle to enable/disable all IceShrimp compatibility workarounds\.\n        Toggle\("settings\.content\.iceshrimp\.workarounds", isOn: \$userPreferences\.useIceShrimpWorkarounds\)\n        if userPreferences\.useIceShrimpWorkarounds \{\n', '', text)
text = text.replace('          }\n        }\n      } header: {', '          }\n      } header: {')

with open('IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift', 'w') as f:
    f.write(text)


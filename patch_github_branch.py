import re

with open('IceCubesApp/App/Tabs/Settings/SettingsTab.swift', 'r') as f:
    content = f.read()

content = content.replace(
    'https://github.com/jadetheda/IceCubesApp',
    'https://github.com/jadetheda/IceCubesApp/tree/multi-spec-support'
)

with open('IceCubesApp/App/Tabs/Settings/SettingsTab.swift', 'w') as f:
    f.write(content)

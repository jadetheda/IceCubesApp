import re

with open('IceCubesApp/App/Tabs/Settings/SettingsTab.swift', 'r') as f:
    content = f.read()

content = content.replace(
    'https://github.com/Dimillian/IceCubesApp',
    'https://github.com/jadetheda/IceCubesApp'
)

with open('IceCubesApp/App/Tabs/Settings/SettingsTab.swift', 'w') as f:
    f.write(content)

import re

with open('IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift', 'r') as f:
    content = f.read()

autoplay_toggle = """        Toggle(isOn: $userPreferences.autoPlayVideo) {
          Text("settings.other.autoplay-video")
        }"""
content = content.replace(
    autoplay_toggle,
    autoplay_toggle + '\n        Toggle(isOn: $userPreferences.loopVideo) {\n          Text("settings.other.loop-video")\n        }'
)

with open('IceCubesApp/App/Tabs/Settings/ContentSettingsView.swift', 'w') as f:
    f.write(content)

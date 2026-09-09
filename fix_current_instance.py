import re

with open('Packages/Env/Sources/Env/CurrentInstance.swift', 'r') as f:
    text = f.read()

text = text.replace('!UserPreferences.shared.iceShrimpShowIncompatibleButtons', 'client?.isIceShrimpWorkaroundsEnabled == true')

with open('Packages/Env/Sources/Env/CurrentInstance.swift', 'w') as f:
    f.write(text)


import re

with open('Packages/Env/Sources/Env/UserPreferences.swift', 'r') as f:
    text = f.read()

text = re.sub(r'    @AppStorage\("use_iceshrimp_workarounds"\) public var useIceShrimpWorkarounds: Bool = false\n', '', text)
text = re.sub(r'  public var useIceShrimpWorkarounds: Bool \{\n    didSet \{\n      storage\.useIceShrimpWorkarounds = useIceShrimpWorkarounds\n    \}\n  \}\n', '', text)
text = re.sub(r'    useIceShrimpWorkarounds = storage\.useIceShrimpWorkarounds\n', '', text)

with open('Packages/Env/Sources/Env/UserPreferences.swift', 'w') as f:
    f.write(text)


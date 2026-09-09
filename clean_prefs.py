import re

with open('Packages/Env/Sources/Env/UserPreferences.swift', 'r') as f:
    text = f.read()

# Remove the storage properties
for var_name in ['iceShrimpHideBoostsButton', 'iceShrimpHideIncompatibleButtons', 'neverLoadVideo', 'tagGroupsClientSideMergeEnabled', 'iceShrimpTrending']:
    text = re.sub(r'    @AppStorage\(".*?"\) public var ' + var_name + r'.*?\n', '', text)

# Remove the public vars and didSets
text = re.sub(r'  public var iceShrimpShowBoostsButton: Bool \{\n    didSet \{\n      storage\.iceShrimpHideBoostsButton = !iceShrimpShowBoostsButton\n    \}\n  \}\n', '', text)
text = re.sub(r'  public var iceShrimpShowIncompatibleButtons: Bool \{\n    didSet \{\n      storage\.iceShrimpHideIncompatibleButtons = !iceShrimpShowIncompatibleButtons\n    \}\n  \}\n', '', text)
text = re.sub(r'  public var neverLoadVideo: Bool \{\n    didSet \{\n      storage\.neverLoadVideo = neverLoadVideo\n    \}\n  \}\n', '', text)
text = re.sub(r'  public var tagGroupsClientSideMergeEnabled: Bool \{\n    didSet \{\n      storage\.tagGroupsClientSideMergeEnabled = tagGroupsClientSideMergeEnabled\n    \}\n  \}\n', '', text)
text = re.sub(r'  public var iceShrimpTrending: Bool \{\n    didSet \{\n      storage\.iceShrimpTrending = iceShrimpTrending\n    \}\n  \}\n', '', text)

# Remove from reload()
text = re.sub(r'    iceShrimpShowBoostsButton = !storage\.iceShrimpHideBoostsButton\n', '', text)
text = re.sub(r'    iceShrimpShowIncompatibleButtons = !storage\.iceShrimpHideIncompatibleButtons\n', '', text)
text = re.sub(r'    neverLoadVideo = storage\.neverLoadVideo\n', '', text)
text = re.sub(r'    tagGroupsClientSideMergeEnabled = storage\.tagGroupsClientSideMergeEnabled\n', '', text)
text = re.sub(r'    iceShrimpTrending = storage\.iceShrimpTrending\n', '', text)

with open('Packages/Env/Sources/Env/UserPreferences.swift', 'w') as f:
    f.write(text)


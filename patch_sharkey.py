import re

with open('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', 'r') as f:
    content = f.read()

# Add sharkey to misskey block
content = content.replace(
    'if name.contains("misskey") || name.contains("firefish") || name.contains("calckey") {',
    'if name.contains("misskey") || name.contains("firefish") || name.contains("calckey") || name.contains("sharkey") {'
)

with open('Packages/NetworkClient/Sources/NetworkClient/FediverseClient.swift', 'w') as f:
    f.write(content)

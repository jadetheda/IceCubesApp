import re
with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MastodonBackend.swift', 'r') as f:
    text = f.read()

start_str = "  public var isIceShrimpWorkaroundsEnabled: Bool {"
end_str = "  public var connections: Set<String> {"
start_idx = text.find(start_str)
end_idx = text.find(end_str)

replacement = """  public var isIceShrimpWorkaroundsEnabled: Bool {
    get { self is IceShrimpBackend }
    set { }
  }
  
  public var connections: Set<String> {"""

text = text[:start_idx] + replacement + text[end_idx + len(end_str):]

with open('Packages/NetworkClient/Sources/NetworkClient/Backends/MastodonBackend.swift', 'w') as f:
    f.write(text)


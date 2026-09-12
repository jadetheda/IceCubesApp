import sys
import datetime

log_entry = f"""- {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}: Fixed Codemagic Exit Code 65 where `UserPreferences` had no member `useIceShrimpWorkarounds` and `FediverseClient` had no member `isIceShrimpWorkaroundsEnabled`. This was due to leftover UI-level IceShrimp checks in `CurrentInstance.swift` and `Router.swift` after the IceShrimp adapter refactor. Removed these checks completely so the UI relies on the `FediverseClient` adapter natively.
"""

with open('memory.md', 'r') as f:
    content = f.read()

insert_pos = content.find("## \ud83e\udeb5 Activity Log")
if insert_pos != -1:
    insert_pos += len("## \ud83e\udeb5 Activity Log")
    new_content = content[:insert_pos] + "\n" + log_entry + content[insert_pos:]
    with open('memory.md', 'w') as f:
        f.write(new_content)
else:
    with open('memory.md', 'a') as f:
        f.write("\n## 🪵 Activity Log\n" + log_entry)

print("memory.md updated.")

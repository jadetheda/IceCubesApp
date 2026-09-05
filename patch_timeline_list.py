import re

with open('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', 'r') as f:
    tlv = f.read()

# Find the List { block
list_start = tlv.find('      List {')
list_end = tlv.find('      .id(client.id)')

list_content = tlv[list_start:list_end]
# Extract the inside of the List
inside = list_content[list_content.find('List {\n')+7 : list_content.rfind('      }\n')]
# Remove 2 spaces of indentation from inside to use as template
inside_unindented = "\n".join(line[2:] if line.startswith("  ") else line for line in inside.split("\n"))

new_block = f"""      Group {{
        if TimelineContentFilter.shared.isGalleryMode {{
          ScrollView {{
            LazyVStack(spacing: 0) {{
{inside}
            }}
          }}
        }} else {{
          List {{
{inside}
          }}
        }}
      }}
"""

new_tlv = tlv[:list_start] + new_block + tlv[list_end:]

with open('Packages/Timeline/Sources/Timeline/View/TimelineListView.swift', 'w') as f:
    f.write(new_tlv)

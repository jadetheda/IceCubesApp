import os

def rewrite(path):
    with open(path, "r") as f:
        lines = f.readlines()
    
    # Move the 'fixup' commit (the last one) right after the 'feat' commit
    new_lines = []
    fixup_line = None
    for line in lines:
        if "fixup" in line:
            fixup_line = line.replace("pick ", "fixup ")
        else:
            new_lines.append(line)
            
    final_lines = []
    for line in new_lines:
        final_lines.append(line)
        if "feat: add localized" in line and fixup_line:
            final_lines.append(fixup_line)
            
    with open(path, "w") as f:
        f.writelines(final_lines)

if __name__ == "__main__":
    import sys
    rewrite(sys.argv[1])

import re

with open('NOBO_Line_Monitor_utf8.ahk', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip_next = False
for i, line in enumerate(lines):
    if "Global LastProcessedTimestamp := 0" in line:
        if any("Global LastProcessedTimestamp := 0" in l for l in new_lines):
            continue
    if "if (CurrentCount > LastFileCount) {" in line and i > 0 and "if (CurrentCount > LastFileCount) {" in lines[i-1]:
        # Detect duplicated blocks
        continue
    new_lines.append(line)

# Clean up duplicated TikrintiKataloga logic manually if regex failed
content = "".join(new_lines)
# Remove the duplicated block that I see in the previous read_file output
content = re.sub(r'\}\s+if \(CurrentCount > LastFileCount\) \{.*?\}\s+LastFileCount := CurrentCount\n\}', '}\n    LastFileCount := CurrentCount\n}', content, flags=re.DOTALL)

with open('NOBO_Line_Monitor_utf8.ahk', 'w', encoding='utf-8') as f:
    f.write(content)

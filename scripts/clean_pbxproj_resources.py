#!/usr/bin/env python3
from pathlib import Path
p = Path('Chisme.xcodeproj/project.pbxproj')
text = p.read_text()
# patterns to remove lines containing
bad_patterns = [
    'AppIcon.appiconset/AppIcon.icns',
    'Assets.xcassets/AppIcon.appiconset/AppIcon.icns in Resources',
    '/* AppIcon.icns',
]
lines = text.splitlines()
new_lines = []
removed = 0
for line in lines:
    if any(pat in line for pat in bad_patterns):
        removed += 1
        continue
    new_lines.append(line)
if removed:
    p.write_text('\n'.join(new_lines) + '\n')
print(f'Removed {removed} matching lines from {p}')

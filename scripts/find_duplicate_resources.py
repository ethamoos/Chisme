#!/usr/bin/env python3
import re
from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'Chisme.xcodeproj' / 'project.pbxproj'
text = p.read_text()
# Map buildFile ID -> fileRef ID
bf_pattern = re.compile(r"([A-F0-9]+)\s*/\*\s*(.*?)\s*in Resources\s*\*/\s*=\s*\{isa = PBXBuildFile; fileRef = ([A-F0-9]+)")
# Map fileRef ID -> path
fr_pattern = re.compile(r"([A-F0-9]+)\s*/\*\s*(.*?)\s*\*/\s*=\s*\{isa = PBXFileReference;.*?path = (.*?);", re.S)
bf = {m.group(1): m.group(3) for m in bf_pattern.finditer(text)}
fr = {m.group(1): m.group(3) for m in fr_pattern.finditer(text)}
# Build list of resource paths
resources = []
for build_id, file_ref in bf.items():
    path = fr.get(file_ref, None)
    resources.append((build_id, file_ref, path))
# Also include plain fileRefs that are in Resources build phase files list
# Find files listed in PBXResourcesBuildPhase
res_phase = re.search(r"/\* Begin PBXResourcesBuildPhase section \*/.*?/\* End PBXResourcesBuildPhase section \*/", text, re.S)
if res_phase:
    block = res_phase.group(0)
    ids = re.findall(r"([A-F0-9]{24})\s*/\*.*?in Resources\s*\*/", block)
    for id in ids:
        # if id already added skip
        if any(r[0]==id for r in resources):
            continue
        # try to find fileRef for this build id
        # sometimes the id is a build file id, sometimes fileRef id
        file_ref = bf.get(id, None)
        if file_ref:
            path = fr.get(file_ref, None)
            resources.append((id, file_ref, path))
        else:
            # maybe the id is actually a fileRef
            path = fr.get(id, None)
            resources.append((id, None, path))
# group by destination basename
from collections import defaultdict
byname = defaultdict(list)
for build_id, file_ref, path in resources:
    if not path:
        dest = None
    else:
        dest = Path(path).name
    byname[dest].append((build_id, file_ref, path))
# print duplicates
print('Resource entries found:')
for dest, items in byname.items():
    print(dest, '->', len(items))
print('\nDuplicates (more than 1 mapping to same destination name):')
for dest, items in byname.items():
    if dest is None:
        continue
    if len(items) > 1:
        print('\nDEST:', dest)
        for it in items:
            print('  ', it)

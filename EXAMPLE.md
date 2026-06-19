# Chisme Example Workflow

This document provides a detailed example of how Chisme works with real file and folder structures.

## File Management: Sort Files

Use **Sort Files** when you want Chisme to move matched files into existing folders inside a single target location.

For example, move `John_essay` to `John_folder`.

The **Target Folder** is the overall destination for all folders. Using the example above, assume the target is:

`/Users/currentUser/Downloads`

Chisme assumes `John_folder` already exists inside that target folder.

## Scenario: Organizing Student Essays

You're a teacher who has received essays from students. All essays are in your Downloads folder, and you want to move each essay to the respective student's folder.

### Before: Initial State

**Source Folder** (`~/Downloads`):
```
~/Downloads/
├── John_essay.pdf
├── Joseph_essay.docx
├── Bill_essay.txt
├── Frank_essay.pdf
├── vacation_photo.jpg     (won't be moved - no match)
└── tmp.txt                (won't be moved - name too short)
```

**Target Folder** (`~/Documents/Students`):
```
~/Documents/Students/
├── johns_work/
├── joseph_work/
├── bills_work/
├── franks_work/
└── mary_work/             (no matching file to move here)
```

### Matching Process

When you click "Move Files", Chisme performs the following:

1. **Scans Source Folder**:
   - Finds 6 files
   - Filters out files that are too short (< 4 characters)
   - Working with: `John_essay.pdf`, `Joseph_essay.docx`, `Bill_essay.txt`, `Frank_essay.pdf`, `vacation_photo.jpg`

2. **Scans Target Folder**:
   - Finds 5 subdirectories
   - All folders are valid (>= 4 characters)
   - Working with: `johns_work`, `joseph_work`, `bills_work`, `franks_work`, `mary_work`

3. **Matches Files to Folders**:

   | File | First 4 Chars | Folder | First 4 Chars | Match? |
   |------|---------------|--------|---------------|--------|
   | John_essay.pdf | `john` | johns_work | `john` | ✅ Yes |
   | Joseph_essay.docx | `jose` | joseph_work | `jose` | ✅ Yes |
   | Bill_essay.txt | `bill` | bills_work | `bill` | ✅ Yes |
   | Frank_essay.pdf | `fran` | franks_work | `fran` | ✅ Yes |
   | vacation_photo.jpg | `vaca` | johns_work | `john` | ❌ No |
   | vacation_photo.jpg | `vaca` | joseph_work | `jose` | ❌ No |
   | vacation_photo.jpg | `vaca` | bills_work | `bill` | ❌ No |
   | vacation_photo.jpg | `vaca` | franks_work | `fran` | ❌ No |
   | vacation_photo.jpg | `vaca` | mary_work | `mary` | ❌ No |

4. **Moves Matched Files**:
   - `John_essay.pdf` → `~/Documents/Students/johns_work/John_essay.pdf`
   - `Joseph_essay.docx` → `~/Documents/Students/joseph_work/Joseph_essay.docx`
   - `Bill_essay.txt` → `~/Documents/Students/bills_work/Bill_essay.txt`
   - `Frank_essay.pdf` → `~/Documents/Students/franks_work/Frank_essay.pdf`

### After: Final State

**Source Folder** (`~/Downloads`):
```
~/Downloads/
├── vacation_photo.jpg     (not moved - no match)
└── tmp.txt                (not moved - name too short)
```

**Target Folder** (`~/Documents/Students`):
```
~/Documents/Students/
├── johns_work/
│   └── John_essay.pdf     ← Moved here
├── joseph_work/
│   └── Joseph_essay.docx  ← Moved here
├── bills_work/
│   └── Bill_essay.txt     ← Moved here
├── franks_work/
│   └── Frank_essay.pdf    ← Moved here
└── mary_work/             (empty - no matching file)
```

### Results Display in App

The app would show:

```
✓ John_essay.pdf moved to johns_work
✓ Joseph_essay.docx moved to joseph_work
✓ Bill_essay.txt moved to bills_work
✓ Frank_essay.pdf moved to franks_work

Summary: 4 of 4 file(s) moved successfully
```

## Example 2: Case Insensitive Matching

**Source Folder**:
```
~/Downloads/
├── ALICE_report.pdf
├── Bob_notes.txt
├── charlie_homework.docx
```

**Target Folder**:
```
~/Projects/
├── Alice_Project/
├── bob_project/
├── CHARLIE_PROJECT/
```

**Matching**:
- `ALICE_report.pdf` (alice) → `Alice_Project` (alice) ✅
- `Bob_notes.txt` (bob_) → `bob_project` (bob_) ✅
- `charlie_homework.docx` (char) → `CHARLIE_PROJECT` (char) ✅

All files match because the comparison is case-insensitive!

## Example 3: No Matches

**Source Folder**:
```
~/Downloads/
├── report.pdf
├── document.txt
```

**Target Folder**:
```
~/Archive/
├── 2023/
├── 2024/
```

**Result**: 
```
Error: No matching files found. Ensure file names match folder names (minimum 4 characters).
```

**Why?**: 
- `report.pdf` (repo) doesn't match `2023` (2023) or `2024` (2024)
- `document.txt` (docu) doesn't match `2023` (2023) or `2024` (2024)

## Example 4: Multiple Potential Matches

**Source Folder**:
```
~/Downloads/
├── test_file.pdf
```

**Target Folder**:
```
~/Folders/
├── test_folder_1/
├── test_folder_2/
├── testing_area/
```

**Result**: 
- `test_file.pdf` → `test_folder_1/` (first match wins)

**Note**: The file matches all three folders (`test`), but only the first one found is used.

## Tips for Organizing Files

### Good Naming Patterns

✅ **Consistent Prefixes**:
```
Files:                  Folders:
- john_essay.pdf    →   johns_work/
- john_homework.txt →   johns_work/
- mary_essay.pdf    →   marys_work/
- mary_homework.txt →   marys_work/
```

✅ **Clear Student IDs**:
```
Files:                  Folders:
- S001_assignment.pdf → S001_Smith_John/
- S002_assignment.pdf → S002_Doe_Jane/
```

### Naming Patterns to Avoid

❌ **Too Short**:
```
Files:              Folders:
- joe_essay.pdf  →  jo_work/     (only 2 chars match)
```

❌ **No Common Pattern**:
```
Files:                  Folders:
- essay_john.pdf    →   johns_work/     (prefix is "essa" vs "john")
- homework_mary.pdf →   marys_work/     (prefix is "home" vs "mary")
```

❌ **Ambiguous Prefixes**:
```
Files:                  Folders:
- test_data.pdf     →   test_results/
                        test_archive/
                        test_backup/
(Hard to predict which folder will be chosen!)
```

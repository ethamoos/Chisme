# Chisme Features and Usage

## Application Overview

Chisme is a macOS file organizer that automatically moves files from a source folder to matching subfolders in a target directory based on filename prefix matching.

## User Interface

The app features a simple, intuitive single-window interface:

```
┌─────────────────────────────────────────┐
│      Chisme - File Organizer            │
├─────────────────────────────────────────┤
│                                         │
│  Source Folder:                         │
│  ┌───────────────────────┐ ┌─────────┐ │
│  │ ~/Downloads           │ │ Browse..│ │
│  └───────────────────────┘ └─────────┘ │
│                                         │
│  Target Folder:                         │
│  ┌───────────────────────┐ ┌─────────┐ │
│  │ No folder selected    │ │ Browse..│ │
│  └───────────────────────┘ └─────────┘ │
│                                         │
│         ┌──────────┐                    │
│         │   Move   │                    │
│         └──────────┘                    │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Status Messages:                │   │
│  │                                 │   │
│  │ ✓ Moved: test.txt -> Testing   │   │
│  │ ✓ Moved: work.pdf -> Work      │   │
│  │                                 │   │
│  │ --- Summary ---                │   │
│  │ Files moved: 2                 │   │
│  │ Errors: 0                      │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Features

### 1. Source Folder Selection
- **Default**: User's Downloads folder
- **Customizable**: Click "Browse..." to select any folder
- **Display**: Shows the full path of the selected folder

### 2. Target Folder Selection
- **Default**: None (must be selected by user)
- **Customizable**: Click "Browse..." to select any folder
- **Display**: Shows the full path of the selected folder

### 3. Move Operation
- **Button**: "Move" button initiates the file organization process
- **Requirements**: Both source and target folders must be selected
- **Processing Indicator**: Shows a spinner while processing
- **Disabled State**: Button is disabled when folders aren't selected or while processing

### 4. File Matching Algorithm
- Scans source folder **1 level deep** (does not recurse into subfolders)
- Scans target folder **1 level deep** for subfolders only
- Matches files to folders based on **first 4 characters**
- **Case-insensitive** matching
- Files with less than 4 characters in their name are **skipped**
- Target folders with less than 4 characters are **skipped**

### 5. Status Display
- **Real-time Updates**: Shows each file as it's being moved
- **Success Indicator**: ✓ symbol for successful moves
- **Error Indicator**: ✗ symbol for failed moves
- **Warning Indicator**: ⚠️ symbol for existing files
- **Summary**: Final count of moved files and errors
- **Scrollable**: Can view all operations even with many files

## Example Use Cases

### Use Case 1: Organizing Downloads
**Scenario**: You have many files in your Downloads folder that need to be organized into project folders.

**Setup**:
- Source: `~/Downloads`
- Target: `~/Projects` (containing subfolders: `Testing`, `Work Files`, `Documentation`)

**Sample Files in Downloads**:
- `test_report_2024.pdf`
- `work_summary.docx`
- `docs_overview.txt`
- `random_file.png` (no match)

**Result**:
- `test_report_2024.pdf` → `~/Projects/Testing/`
- `work_summary.docx` → `~/Projects/Work Files/`
- `docs_overview.txt` → `~/Projects/Documentation/`
- `random_file.png` → Remains in Downloads (no matching folder)

### Use Case 2: Photo Organization
**Scenario**: Organizing photos by event type.

**Setup**:
- Source: `~/Desktop/New Photos`
- Target: `~/Pictures/Events` (containing: `Birthday_2024`, `Wedding_Photos`, `Vacation_2024`)

**Sample Files**:
- `birthday_cake.jpg`
- `wedding_ceremony.jpg`
- `vacation_beach.jpg`

**Result**:
- `birthday_cake.jpg` → `~/Pictures/Events/Birthday_2024/`
- `wedding_ceremony.jpg` → `~/Pictures/Events/Wedding_Photos/`
- `vacation_beach.jpg` → `~/Pictures/Events/Vacation_2024/`

## Error Handling

The app handles several error conditions gracefully:

1. **File Already Exists**: If a file with the same name already exists in the destination folder, the file is skipped and a warning is displayed.

2. **Permission Errors**: If the app lacks permission to read the source or write to the target, an error message is shown.

3. **Invalid Paths**: If folders are deleted or become inaccessible during operation, appropriate errors are displayed.

4. **No Matches**: Files that don't match any folder are simply left in the source location.

## Safety Features

- **No Overwriting**: Existing files are never overwritten
- **Move Operation**: Files are moved (not copied) to save disk space
- **Non-destructive**: Files that don't match remain in the source folder
- **No Recursion**: Only processes top-level items to prevent accidental deep-tree operations

## Technical Details

- **Platform**: macOS Ventura (13.0) and later
- **Framework**: SwiftUI
- **Language**: Swift 6.2
- **Architecture**: Swift Package Manager executable
- **Minimum Window Size**: 500x450 pixels
- **Thread Safety**: File operations run on background thread to keep UI responsive

# Chisme

A macOS Ventura-compatible SwiftUI application that enables users to manage files between source and target folders with an intuitive interface.

## Features

- **Folder Selection**: Select source (defaults to Downloads) and target folders
- **Smart File Matching**: Automatically matches files to folders based on name similarity (minimum 4 characters)
- **File Moving**: Move matched files to their corresponding target folders with a single click
- **Real-time Feedback**: View detailed results of file operations with success/error indicators
- **Quick Access**: Open the target folder directly from the app

## Requirements

- macOS Ventura (13.0) or later
- Xcode 14.0 or later (for building)
- Swift 5.7 or later

## Building and Running

### Using Xcode

1. Open `Chisme.xcodeproj` in Xcode
2. Select the "Chisme" scheme
3. Press Cmd+R to build and run

### Using Swift Package Manager

```bash
swift build
swift run Chisme
```

## How It Works

1. **Select Source Folder**: Choose the folder containing files you want to organize (defaults to Downloads)
2. **Select Target Folder**: Choose the folder containing subfolders where files should be moved
3. **Click "Move Files"**: The app will:
   - Scan the source folder for files (non-recursive, 1-level deep)
   - Scan the target folder for matching subdirectories (1-level deep)
   - Match files to folders based on the first 4+ characters of their names
   - Move matched files to their respective folders
   - Display a summary of all operations

### Example

**Source Folder (~/Downloads):**
- `John_essay.pdf`
- `Joseph_essay.docx`
- `Bill_essay.txt`
- `Frank_essay.pdf`

**Target Folder:**
- `johns_work/`
- `joseph_work/`
- `bills_work/`
- `franks_work/`

**Result:**
- `John_essay.pdf` → `johns_work/John_essay.pdf`
- `Joseph_essay.docx` → `joseph_work/Joseph_essay.docx`
- `Bill_essay.txt` → `bills_work/Bill_essay.txt`
- `Frank_essay.pdf` → `franks_work/Frank_essay.pdf`

## License

See LICENSE file for details.
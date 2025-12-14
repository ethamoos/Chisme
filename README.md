# Chisme

A simple macOS file organizer app that automatically moves files from a source folder to matching target folders based on filename prefixes.

## Requirements

- macOS Ventura (13.0) or later
- Xcode 14 or later
- Swift 6.2 or later

## Features

- Select a source folder (defaults to Downloads)
- Select a target folder containing subfolders
- Click "Move" to automatically organize files
- Files are matched to folders based on their first 4 characters (case-insensitive)
- Real-time status updates showing which files were moved
- Error handling for duplicate files and move failures

## Building and Running

### Using Swift Package Manager

```bash
swift build
swift run
```

### Using Xcode

1. Open the project folder in Xcode
2. File > Open > Select the Chisme folder
3. Build and run the project (⌘R)

## How It Works

1. The app scans the source folder (1 level deep) for files
2. It scans the target folder (1 level deep) for subfolders
3. For each file in the source folder, it checks if the first 4 characters of the filename match the first 4 characters of any subfolder name in the target folder
4. When a match is found, the file is moved to that subfolder
5. The app displays the results in the status window

## Example

If your source folder contains:
- `test_data.txt`
- `work_document.pdf`

And your target folder contains subfolders:
- `Testing/`
- `Work Files/`

The app will:
- Move `test_data.txt` to `Testing/` (matches "test")
- Move `work_document.pdf` to `Work Files/` (matches "work")

## License

MIT
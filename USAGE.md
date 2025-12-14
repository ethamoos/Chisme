# Chisme Usage Guide

## Overview

Chisme is a simple yet powerful macOS application designed to help you organize files by automatically moving them to matching folders based on filename patterns.

## User Interface

The application window consists of the following sections:

### 1. Source Folder Selection
- **Purpose**: Select the folder containing files you want to organize
- **Default**: Automatically set to your Downloads folder
- **Button**: "Select Folder" to choose a different source location
- **Display**: Shows the full path of the selected folder

### 2. Target Folder Selection
- **Purpose**: Select the folder containing subfolders where files should be moved
- **Button**: "Select Folder" to choose the target location
- **Button**: "Open" (appears after selection) to open the target folder in Finder
- **Display**: Shows the full path of the selected folder

### 3. Move Files Button
- **Purpose**: Initiates the file matching and moving process
- **State**: Disabled until both source and target folders are selected
- **Processing**: Shows "Processing..." with a spinner while working
- **Action**: 
  1. Scans source folder for files
  2. Scans target folder for matching subdirectories
  3. Matches files to folders based on name similarity
  4. Moves matched files to their respective folders

### 4. Results Display
- **Success Indicators**: Green checkmark for successfully moved files
- **Error Indicators**: Red X for files that failed to move
- **Details**: Shows which file moved to which folder
- **Summary**: Total count of successful vs. failed moves
- **Error Messages**: Displays any errors that occurred during processing

## Matching Algorithm

The app uses a smart matching algorithm to pair files with folders:

- **Minimum Match Length**: 4 characters
- **Case Insensitive**: "John" matches "johns" and "JOHN" matches "johns"
- **Prefix Matching**: The file name must start with the same first 4 characters as the folder name
- **First Match Wins**: If multiple folders match, the first one found is used

### Examples

| File Name | Folder Name | Match? |
|-----------|-------------|--------|
| `John_essay.pdf` | `johns_work` | ✅ Yes (john → john) |
| `Joseph_report.docx` | `joseph_work` | ✅ Yes (jose → jose) |
| `Bill_notes.txt` | `bills_work` | ✅ Yes (bill → bill) |
| `Amy_file.pdf` | `Amy_folder` | ✅ Yes (amy_ → amy_) |
| `test.txt` | `testing` | ❌ No (too short) |
| `alice_doc.pdf` | `bob_work` | ❌ No (different prefixes) |

## Step-by-Step Workflow

1. **Launch the App**: Open Chisme from your Applications folder

2. **Verify Source Folder**: 
   - The app defaults to your Downloads folder
   - Click "Select Folder" if you want to choose a different source

3. **Select Target Folder**:
   - Click "Select Folder" in the Target Folder section
   - Navigate to the folder containing your organized subfolders
   - Click "Choose" to confirm

4. **Review Your Folders**:
   - Verify the displayed paths are correct
   - Use the "Open" button to inspect the target folder if needed

5. **Move Files**:
   - Click the "Move Files" button
   - Wait for the processing to complete (usually instant for small numbers of files)
   - Review the results displayed in the Results section

6. **Check Results**:
   - Green checkmarks indicate successful moves
   - Red X marks indicate failures (with error messages)
   - The summary shows the total count

7. **Open Target Folder** (Optional):
   - Click the "Open" button next to the target folder path
   - Verify files are in their expected locations

## Tips and Best Practices

- **Backup First**: Always backup important files before moving them
- **Test with Copies**: Try the app with copies of files first to ensure it works as expected
- **Organize Target Folders**: Create well-named target folders with clear prefixes
- **Check Results**: Always review the results display to ensure files moved correctly
- **File Conflicts**: If a file with the same name already exists in the target folder, it will be replaced

## Troubleshooting

### "No matching files found" Error
- **Cause**: No files in the source folder match any folders in the target folder
- **Solution**: 
  - Ensure file names and folder names share at least 4 characters
  - Check that file names are at least 4 characters long
  - Verify folders in the target directory are at least 4 characters long

### Files Not Moving
- **Cause**: Permissions issue or file in use
- **Solution**: 
  - Check that you have write permissions to the target folder
  - Close any applications that might be using the files
  - Check the error message displayed for specific details

### Wrong Folder Match
- **Cause**: Multiple folders start with the same 4 characters
- **Solution**: 
  - Rename folders to have more distinctive prefixes
  - Move files manually if needed

## Keyboard Shortcuts

- **Cmd+Q**: Quit the application

## Privacy and Security

- **Local Only**: All operations happen locally on your Mac
- **No Network**: The app doesn't send any data over the network
- **Permissions**: The app only accesses folders you explicitly select
- **Hardened Runtime**: Built with macOS security features enabled

# Quick Start Guide

Get up and running with Chisme in minutes!

## Installation

### Prerequisites
- macOS Ventura (13.0) or later
- Xcode 14+ (for building from source)

### Build and Run

1. **Clone the repository**
   ```bash
   git clone https://github.com/ethamoos/Chisme.git
   cd Chisme
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```

3. **Run the app**
   - Press `⌘R` or click the Run button in Xcode
   - Or build from command line: `swift run`

## First Use

### Step 1: Select Source Folder
- The app defaults to your Downloads folder
- Click "Browse..." next to "Source Folder" to choose a different folder

### Step 2: Select Target Folder
- Click "Browse..." next to "Target Folder"
- Choose a folder that contains subfolders for organization

### Step 3: Click Move
- Press the "Move" button
- Watch the status window for real-time updates
- Files will be automatically moved to matching folders

## Example Workflow

Let's say you want to organize files from Downloads:

1. **Your Downloads folder contains:**
   - `test_data.csv`
   - `work_report.pdf`
   - `project_notes.txt`

2. **Your Projects folder contains subfolders:**
   - `Testing/`
   - `Work Documents/`
   - `Project Files/`

3. **Run Chisme:**
   - Source: `~/Downloads`
   - Target: `~/Projects`
   - Click "Move"

4. **Result:**
   - `test_data.csv` → `Projects/Testing/`
   - `work_report.pdf` → `Projects/Work Documents/`
   - `project_notes.txt` → `Projects/Project Files/`

## Matching Rules

Files are matched to folders based on their **first 4 characters** (case-insensitive):

| File Name | Folder Name | Match? |
|-----------|-------------|--------|
| `test_file.txt` | `Testing` | ✅ Yes (`test` = `Test`) |
| `work_doc.pdf` | `Work Files` | ✅ Yes (`work` = `Work`) |
| `abc.txt` | `ABCD` | ❌ No (file too short) |
| `file.txt` | `ABC` | ❌ No (folder too short) |
| `random.txt` | `Testing` | ❌ No (`rand` ≠ `test`) |

## Tips

- **Organize gradually**: Start with a small number of files to test your folder structure
- **Backup first**: Consider backing up important files before organizing
- **Create clear folder names**: Use descriptive names with at least 4 unique starting characters
- **Review the log**: Check the status window to see what was moved
- **Existing files**: If a file already exists in the target, it won't be overwritten

## Troubleshooting

**"Move button is disabled"**
- Make sure both source and target folders are selected

**"No files were moved"**
- Check that your source folder contains files (not just folders)
- Verify that target folder has subfolders with names that match your files
- Remember: minimum 4 characters must match

**"Permission denied"**
- Grant the app permission in System Settings > Privacy & Security > Files and Folders

## Need More Help?

- See [FEATURES.md](FEATURES.md) for detailed feature documentation
- See [BUILD.md](BUILD.md) for detailed build instructions
- Check [README.md](README.md) for general information

import SwiftUI
import Foundation
import AppKit

/// Main view for the Chisme file organizer app.
/// Allows users to select source and target folders and move files based on filename matching.
public struct ContentView: View {
    @State private var sourceFolder: URL?
    @State private var targetFolder: URL?
    @State private var statusMessage: String = ""
    @State private var isProcessing: Bool = false
    
    public init() {
        // Set default source folder to user's Downloads folder
        _sourceFolder = State(initialValue: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first)
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Chisme - File Organizer")
                .font(.title)
                .padding(.top)
            
            // Source Folder Selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Source Folder:")
                    .font(.headline)
                
                HStack {
                    Text(sourceFolder?.path ?? "No folder selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                    
                    Button("Browse...") {
                        selectSourceFolder()
                    }
                }
            }
            .padding(.horizontal)
            
            // Target Folder Selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Target Folder:")
                    .font(.headline)
                
                HStack {
                    Text(targetFolder?.path ?? "No folder selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                    
                    Button("Browse...") {
                        selectTargetFolder()
                    }
                }
            }
            .padding(.horizontal)
            
            // Move Button
            Button(action: moveFiles) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 16, height: 16)
                } else {
                    Text("Move")
                        .frame(width: 100)
                }
            }
            .disabled(sourceFolder == nil || targetFolder == nil || isProcessing)
            .buttonStyle(.borderedProminent)
            .padding()
            
            // Status Message
            ScrollView {
                Text(statusMessage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(5)
            }
            .frame(height: 200)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(minWidth: 500, minHeight: 450)
        .padding()
    }
    
    private func selectSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = sourceFolder
        
        if panel.runModal() == .OK {
            sourceFolder = panel.url
        }
    }
    
    private func selectTargetFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = targetFolder
        
        if panel.runModal() == .OK {
            targetFolder = panel.url
        }
    }
    
    private func moveFiles() {
        guard let source = sourceFolder, let target = targetFolder else {
            statusMessage = "Error: Both source and target folders must be selected."
            return
        }
        
        isProcessing = true
        statusMessage = "Starting file move operation...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                
                // Get contents of source folder (1 level deep)
                let sourceContents = try fileManager.contentsOfDirectory(
                    at: source,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                
                // Get folders in target directory (1 level deep)
                let targetContents = try fileManager.contentsOfDirectory(
                    at: target,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                
                // Filter to get only directories in target
                let targetFolders = targetContents.filter { url in
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    return isDirectory.boolValue
                }
                
                var movedCount = 0
                var errorCount = 0
                
                // Process each item in source folder
                for sourceItem in sourceContents {
                    let sourceItemName = sourceItem.lastPathComponent
                    
                    // Check if it's a file (not a directory)
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: sourceItem.path, isDirectory: &isDirectory)
                    
                    if isDirectory.boolValue {
                        continue // Skip directories
                    }
                    
                    // Try to find matching folder in target
                    if let matchingFolder = FileMatcher.findMatchingFolder(
                        itemName: sourceItemName,
                        targetFolders: targetFolders
                    ) {
                        do {
                            let destinationURL = matchingFolder.appendingPathComponent(sourceItemName)
                            
                            // Check if file already exists at destination
                            if fileManager.fileExists(atPath: destinationURL.path) {
                                DispatchQueue.main.async {
                                    statusMessage += "⚠️  File already exists: \(sourceItemName) -> \(matchingFolder.lastPathComponent)\n"
                                }
                                errorCount += 1
                                continue
                            }
                            
                            // Move the file
                            try fileManager.moveItem(at: sourceItem, to: destinationURL)
                            movedCount += 1
                            
                            DispatchQueue.main.async {
                                statusMessage += "✓ Moved: \(sourceItemName) -> \(matchingFolder.lastPathComponent)\n"
                            }
                        } catch {
                            errorCount += 1
                            DispatchQueue.main.async {
                                statusMessage += "✗ Error moving \(sourceItemName): \(error.localizedDescription)\n"
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    statusMessage += "\n--- Summary ---\n"
                    statusMessage += "Files moved: \(movedCount)\n"
                    statusMessage += "Errors: \(errorCount)\n"
                    statusMessage += "Operation completed.\n"
                    isProcessing = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    statusMessage += "Error: \(error.localizedDescription)\n"
                    isProcessing = false
                }
            }
        }
    }
    
}

#Preview {
    ContentView()
}

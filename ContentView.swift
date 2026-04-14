//
//  ContentView.swift
//  Chisme
//
//  Main view for the file management app
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @State private var sourceFolder: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    @State private var targetFolder: URL?
    @State private var moveResults: [FileMatch] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // Sorting feature state
    @State private var sortingThreshold: Double = 0.8
    @State private var sortingCreateFolders: Bool = true
    @State private var sortingResults: [(URL, [URL])] = []
    @State private var sortingError: String?
    @State private var isSorting: Bool = false
    @State private var sortingTargetFolder: URL?
    @State private var sortingSummary: [(folder: URL, moved: Int, total: Int, failed: [String])] = []

    // FileManagement sub-tab selection: 0 = Move, 1 = Sorting
    @State private var fileManagementMode: Int = 0

    private let fileMatcher = FileMatcher()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Chisme")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 20)

            Divider()

            // Tabs: FileManagement contains the existing UI below the Divider; Custom is a placeholder
            TabView {
                // FileManagement tab: contains two sub-tabs — Move Files and Sorting
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("File Management")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.top, 20)

                        // Sub-tabs: segmented control to switch between Move and Sorting
                        Picker("Mode", selection: $fileManagementMode) {
                            Text("Move Files").tag(0)
                            Text("Sorting").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if fileManagementMode == 0 {
                            // --- Move Files UI (unchanged) ---
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Move Files")
                                    .font(.headline)

                                // Source Folder Selection
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Source Folder:")
                                        .font(.subheadline)

                                    HStack {
                                        Text(sourceFolder?.path ?? "No folder selected")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(sourceFolder != nil ? .primary : .secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button("Select Folder") { selectSourceFolder() }
                                            .buttonStyle(.bordered)
                                    }
                                    .padding(10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Target Folder:")
                                        .font(.subheadline)

                                    HStack {
                                        Text(targetFolder?.path ?? "No folder selected")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(targetFolder != nil ? .primary : .secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button("Select Folder") { selectTargetFolder() }
                                            .buttonStyle(.bordered)

                                        if targetFolder != nil {
                                            Button("Open") { openTargetFolder() }
                                                .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                }

                                HStack {
                                    Spacer()
                                    Button(action: moveFiles) {
                                        HStack {
                                            if isProcessing { ProgressView().scaleEffect(0.7).frame(width: 16, height: 16) }
                                            Text(isProcessing ? "Processing..." : "Move Files")
                                        }
                                        .frame(minWidth: 120)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(sourceFolder == nil || targetFolder == nil || isProcessing)
                                    Spacer()
                                }
                                .padding(.vertical, 10)

                                if let errorMessage = errorMessage {
                                    Text(errorMessage).foregroundColor(.red).font(.subheadline).padding(10).background(Color.red.opacity(0.1)).cornerRadius(8)
                                }

                                if !moveResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Move Results:").font(.headline)
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 6) {
                                                ForEach(moveResults.indices, id: \.self) { index in
                                                    let result = moveResults[index]
                                                    HStack(alignment: .top, spacing: 8) {
                                                        Image(systemName: result.moved ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                            .foregroundColor(result.moved ? .green : .red).frame(width: 20)
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            if result.moved {
                                                                Text("\(result.displayName) moved to \(result.targetFolderName)")
                                                                    .font(.system(.body, design: .monospaced))
                                                            } else {
                                                                Text("\(result.displayName) failed to move").font(.system(.body, design: .monospaced)).foregroundColor(.red)
                                                                if let error = result.error { Text("Error: \(error)").font(.caption).foregroundColor(.secondary) }
                                                            }
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding(8).background(result.moved ? Color.green.opacity(0.1) : Color.red.opacity(0.1)).cornerRadius(6)
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 300).padding(10).background(Color(NSColor.controlBackgroundColor)).cornerRadius(8)
                                        let successCount = moveResults.filter { $0.moved }.count
                                        let totalCount = moveResults.count
                                        Text("Summary: \(successCount) of \(totalCount) file(s) moved successfully").font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            // --- Sorting UI ---
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sorting")
                                    .font(.headline)

                                Text("Group similar items in a target folder by filename similarity.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Target folder to sort:")
                                        Spacer()
                                        if let s = sortingTargetFolder {
                                            Text(s.lastPathComponent).foregroundColor(.secondary)
                                        } else {
                                            Text("None").foregroundColor(.secondary)
                                        }
                                    }

                                    HStack {
                                        Button("Select Sorting Folder") {
                                            if let url = selectFolder() {
                                                sortingTargetFolder = url
                                                sortingResults = []
                                                sortingSummary = []
                                                sortingError = nil
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        Spacer()
                                    }

                                    HStack {
                                        Text("Similarity threshold: \(String(format: "%.2f", sortingThreshold))")
                                        Slider(value: $sortingThreshold, in: 0.5...1.0, step: 0.01)
                                    }

                                    Toggle("Create folders for groups", isOn: $sortingCreateFolders)

                                    HStack {
                                        Spacer()
                                        Button(action: runSorting) {
                                            if isSorting { ProgressView().scaleEffect(0.7).frame(width: 16, height: 16) }
                                            Text(isSorting ? "Sorting..." : "Run Sorting")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(sortingTargetFolder == nil || isSorting)
                                        Spacer()
                                    }
                                }

                                if let sortingError = sortingError {
                                    Text(sortingError).foregroundColor(.red).font(.subheadline).padding(8).background(Color.red.opacity(0.08)).cornerRadius(6)
                                }

                                if !sortingResults.isEmpty {
                                    VStack(alignment: .leading) {
                                        Text("Sorting Results:").font(.headline)
                                        ForEach(sortingResults.indices, id: \.self) { i in
                                            let (folderURL, items) = sortingResults[i]
                                            VStack(alignment: .leading) {
                                                Text("Group: \(folderURL.lastPathComponent) — \(items.count) item(s)")
                                                    .font(.subheadline)
                                                ForEach(items.indices, id: \.self) { j in
                                                    Text(items[j].lastPathComponent).font(.caption).foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(6)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(6)
                                        }

                                        // Show per-group summary (moved/failed)
                                        if !sortingSummary.isEmpty {
                                            Divider()
                                            Text("Summary:").font(.headline)
                                            ForEach(sortingSummary.indices, id: \.self) { k in
                                                let s = sortingSummary[k]
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("\(s.folder.lastPathComponent): moved \(s.moved) of \(s.total)")
                                                        .font(.subheadline)
                                                    if !s.failed.isEmpty {
                                                        Text("Failed to move:") .font(.caption).foregroundColor(.red)
                                                        ForEach(s.failed, id: \.self) { name in
                                                            Text(name).font(.caption2).foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                                .padding(6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .tabItem {
                    Text("FileManagement")
                }

                // Custom tab: placeholder for user customizations
                VStack(alignment: .leading) {
                    Text("Custom")
                        .font(.title2)
                        .padding(.top, 20)
                    Text("Add your custom actions or settings here.")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
//                .padding()    
                .tabItem {
                    Text("Custom")
                }

                // Programizer tab: placeholder for features ported from Programizer app
                ProgramizerView()
                    .tabItem {
                        Text("Programizer")
                    }

                // DMGenius tab: placeholder for features ported from DMGenius app
                DMGeniusView()
                    .tabItem {
                        Text("DMGenius")
                    }
            }
            .frame(minWidth: 600, minHeight: 360)
        }
        .padding()

        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $appState.showingHelp) {
            HelpView()
                .frame(minWidth: 480, minHeight: 360)
        }
    }

    // MARK: - Folder Selection Methods

    private func selectSourceFolder() {
        if let url = selectFolder() {
            sourceFolder = url
            errorMessage = nil
            moveResults = []
        }
    }

    private func selectTargetFolder() {
        if let url = selectFolder() {
            targetFolder = url
            errorMessage = nil
            moveResults = []
        }
    }

    private func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select a folder"

        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }

    // MARK: - File Operations

    private func moveFiles() {
        guard let source = sourceFolder, let target = targetFolder else {
            return
        }

        isProcessing = true
        errorMessage = nil
        moveResults = []

        // Run on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Find matches
                let matches = try fileMatcher.findMatches(sourceFolder: source, targetFolder: target)

                if matches.isEmpty {
                    DispatchQueue.main.async {
                        errorMessage = "No matching files found. Ensure file names match folder names (minimum 4 characters)."
                        isProcessing = false
                    }
                    return
                }

                // Move files
                let results = fileMatcher.moveFiles(matches: matches)

                DispatchQueue.main.async {
                    moveResults = results
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }

    private func openTargetFolder() {
        guard let target = targetFolder else { return }
        NSWorkspace.shared.open(target)
    }

    // MARK: - Sorting

    private func runSorting() {
        guard let target = sortingTargetFolder else { return }

        isSorting = true
        sortingError = nil
        sortingResults = []
        sortingSummary = []

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let groups = try fileMatcher.groupSimilarItems(in: target, scoreThreshold: sortingThreshold, createFolders: sortingCreateFolders)

                // Build a basic summary by checking destination folder contents
                var summary: [(folder: URL, moved: Int, total: Int, failed: [String])] = []
                for (folderURL, items) in groups {
                    var movedCount = 0
                    var failedNames: [String] = []
                    for item in items {
                        let dest = folderURL.appendingPathComponent(item.lastPathComponent)
                        if FileManager.default.fileExists(atPath: dest.path) {
                            movedCount += 1
                        } else {
                            failedNames.append(item.lastPathComponent)
                        }
                    }
                    summary.append((folder: folderURL, moved: movedCount, total: items.count, failed: failedNames))
                }

                DispatchQueue.main.async {
                    sortingResults = groups
                    sortingSummary = summary
                    isSorting = false
                }
            } catch {
                DispatchQueue.main.async {
                    sortingError = "Error: \(error.localizedDescription)"
                    isSorting = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

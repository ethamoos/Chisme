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

    private let fileMatcher = FileMatcher()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Chisme - File Manager")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 20)

            // Source Folder Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Folder:")
                    .font(.headline)

                HStack {
                    Text(sourceFolder?.path ?? "No folder selected")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(sourceFolder != nil ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Select Folder") {
                        selectSourceFolder()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Target Folder Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Folder:")
                    .font(.headline)

                HStack {
                    Text(targetFolder?.path ?? "No folder selected")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(targetFolder != nil ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Select Folder") {
                        selectTargetFolder()
                    }
                    .buttonStyle(.bordered)

                    if targetFolder != nil {
                        Button("Open") {
                            openTargetFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Move Button
            HStack {
                Spacer()

                Button(action: moveFiles) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Text(isProcessing ? "Processing..." : "Move Files")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourceFolder == nil || targetFolder == nil || isProcessing)

                Spacer()
            }
            .padding(.vertical, 10)

            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Results Display
            if !moveResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Move Results:")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(moveResults.indices, id: \.self) { index in
                                let result = moveResults[index]
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: result.moved ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.moved ? .green : .red)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        if result.moved {
                                            Text("\(result.displayName) moved to \(result.targetFolderName)")
                                                .font(.system(.body, design: .monospaced))
                                        } else {
                                            Text("\(result.displayName) failed to move")
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.red)

                                            if let error = result.error {
                                                Text("Error: \(error)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(8)
                                .background(result.moved ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Summary
                    let successCount = moveResults.filter { $0.moved }.count
                    let totalCount = moveResults.count
                    Text("Summary: \(successCount) of \(totalCount) file(s) moved successfully")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(30)
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
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

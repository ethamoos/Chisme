//
//  ContentView.swift
//  DMGenius
//
//  Created by Amos Deane on 10/02/2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var config = DMGConfiguration()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var createdDMGURL: URL?

    // log / debug output for hdiutil
    @State private var showLog = false
    @State private var lastCommand = ""
    @State private var lastStdout = ""
    @State private var lastStderr = ""

    @ObservedObject private var creator = DMGCreator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Source:")
                if let sourcePath = config.sourceURL?.path {
                    TextField("", text: Binding(
                        get: { sourcePath },
                        set: { config.sourceURL = URL(fileURLWithPath: $0) }
                    ))
                    .lineLimit(1)
                    .textFieldStyle(.roundedBorder)
                } else {
                    Text("No file selected")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Choose…") { selectSource() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }

            HStack {
                Text("Output:")
                if let outputPath = config.outputURL?.path {
                    TextField("", text: Binding(
                        get: { outputPath },
                        set: { config.outputURL = URL(fileURLWithPath: $0) }
                    ))
                    .lineLimit(1)
                    .textFieldStyle(.roundedBorder)
                } else {
                    Text("No output chosen")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Choose…") { selectOutput() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }

            HStack {
                Text("Volume name:")
                TextField("Volume name", text: $config.volumeName)
                    .frame(minWidth: 200)
            }

            HStack {
                Text("Install location:")
                Picker("Install location", selection: $config.targetChoice) {
                    ForEach(TargetChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                Spacer()
            }

            if config.targetChoice == .custom {
                HStack {
                    Text("Custom path:")
                    TextField("/Users/alice/Applications", text: Binding(get: { config.customTargetPath ?? "" }, set: { config.customTargetPath = $0 }))
                }
            }

            Toggle(isOn: $config.includeApplicationsSymlink) {
                Text("Include Applications symlink")
            }

            HStack {
                Spacer()
                if creator.isWorking {
                    ProgressView(creator.progressMessage ?? "Working…")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                Button("Create DMG") {
                    createDMG()
                }
                .disabled(creator.isWorking)
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button("Create Structure DMG") {
                    createStructureOnlyDMG()
                }
                .disabled(creator.isWorking)
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            // Small visible hint/link to open the log if present
            if !lastCommand.isEmpty || !lastStdout.isEmpty || !lastStderr.isEmpty {
                HStack {
                    Text("Last hdiutil command:")
                    Text(lastCommand)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Show Log") { showLog = true }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                }
            }
        }
        .padding()
        .frame(minWidth: 600)
        .alert(isPresented: $showAlert) {
            // Provide a Show Log button so users can inspect stdout/stderr when an error occurs
            if let dmgURL = createdDMGURL {
                Alert(
                    title: Text("DMG Creator"),
                    message: Text(alertMessage),
                    primaryButton: .default(Text("Open in Finder")) {
                        NSWorkspace.shared.selectFile(dmgURL.path, inFileViewerRootedAtPath: "")
                    },
                    secondaryButton: .default(Text("OK")) { }
                )
            } else {
                Alert(
                    title: Text("DMG Creator"),
                    message: Text(alertMessage),
                    primaryButton: .default(Text("Show Log")) { showLog = true },
                    secondaryButton: .cancel()
                )
            }
        }
        .sheet(isPresented: $showLog) {
            LogSheet(command: lastCommand, stdout: lastStdout, stderr: lastStderr)
        }
    }

    // MARK: - Actions
    private func selectSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible }) {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    DispatchQueue.main.async {
                        self.config.sourceURL = panel.urls.first
                    }
                }
            }
        } else {
            let response = panel.runModal()
            if response == .OK {
                self.config.sourceURL = panel.urls.first
            }
        }
    }

    private func selectOutput() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["dmg"]
        panel.nameFieldStringValue = config.sourceURL?.deletingPathExtension().lastPathComponent.appending(".dmg") ?? "DMGenius.dmg"

        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible }) {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    DispatchQueue.main.async {
                        self.config.outputURL = url
                    }
                }
            }
        } else {
            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                self.config.outputURL = url
            }
        }
    }

    private func createDMG() {
        // Clear previous log
        lastCommand = ""
        lastStdout = ""
        lastStderr = ""

        creator.createDMG(with: config) { result in
            switch result {
            case .success(let url):
                createdDMGURL = url
                alertMessage = "Created DMG at \(url.path)"
                showAlert = true
            case .failure(let err):
                // If the error is an NSError and contains stdout/stderr in userInfo (added by RealProcessRunner), capture them for the log sheet.
                if let ns = err as NSError? {
                    // The RealProcessRunner sets NSLocalizedDescriptionKey to "Process failed: <cmd>" and adds "stdout"/"stderr" keys.
                    let desc = ns.userInfo[NSLocalizedDescriptionKey] as? String ?? err.localizedDescription
                    lastCommand = desc
                    lastStdout = ns.userInfo["stdout"] as? String ?? ""
                    lastStderr = ns.userInfo["stderr"] as? String ?? ""
                    // also pick up staging/temp paths if present
                    if let staging = ns.userInfo["stagingPath"] as? String { lastStdout = ("Staging: \(staging)\n\n" + lastStdout) }
                    if let tempOut = ns.userInfo["tempOutputPath"] as? String { lastStderr = ("Temp DMG: \(tempOut)\n\n" + lastStderr) }
                } else {
                    lastCommand = err.localizedDescription
                }

                alertMessage = "Failed: \(err.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func createStructureOnlyDMG() {
        // Clear previous log
        lastCommand = ""
        lastStdout = ""
        lastStderr = ""

        creator.createStructureOnlyDMG(with: config) { result in
            switch result {
            case .success(let url):
                createdDMGURL = url
                alertMessage = "Created structure-only DMG at \(url.path)"
                showAlert = true
            case .failure(let err):
                if let ns = err as NSError? {
                    let desc = ns.userInfo[NSLocalizedDescriptionKey] as? String ?? err.localizedDescription
                    lastCommand = desc
                    lastStdout = ns.userInfo["stdout"] as? String ?? ""
                    lastStderr = ns.userInfo["stderr"] as? String ?? ""
                    if let staging = ns.userInfo["stagingPath"] as? String { lastStdout = ("Staging: \(staging)\n\n" + lastStdout) }
                    if let tempOut = ns.userInfo["tempOutputPath"] as? String { lastStderr = ("Temp DMG: \(tempOut)\n\n" + lastStderr) }
                } else {
                    lastCommand = err.localizedDescription
                }

                alertMessage = "Failed: \(err.localizedDescription)"
                showAlert = true
            }
        }
    }
}

struct LogSheet: View {
    let command: String
    let stdout: String
    let stderr: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command:")
                .bold()
            ScrollView {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
            }.frame(height: 60)
                .textSelection(.enabled)


            Text("Standard Output:")
                .bold()
            ScrollView {
                Text(stdout.isEmpty ? "(no stdout)" : stdout)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
            }.frame(minHeight: 100)
                .textSelection(.enabled)


            Text("Standard Error:")
                .bold()
            
            ScrollView {
                Text(stderr.isEmpty ? "(no stderr)" : stderr)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
            }.frame(minHeight: 100)
                .textSelection(.enabled)


            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 420)
    }
}

#Preview {
    ContentView()
}

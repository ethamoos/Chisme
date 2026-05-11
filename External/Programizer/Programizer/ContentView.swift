//
//  ContentView.swift
//  Programizer
//
//  Created by Amos Deane on 21/01/2026.
//

import SwiftUI
import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var manager = DMGManager()
    @AppStorage("relativePath") private var relativePath: String = "/Path/To/AppOrPkg"
    @State private var delaySeconds: Double = 2.0
    @State private var runAsAdmin: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Programizer")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                    Text("Mass-mount and run scripts on DMG volumes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Small quick action buttons on header
                HStack(spacing: 8) {
                    Button(action: { manager.scanForDMGs() }) {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { Task { await manager.mountAll() } }) {
                        Label("Mount All", systemImage: "externaldrive.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                }
            }
            .padding(.horizontal)

            HStack(alignment: .top, spacing: 16) {
                // Left panel: configuration
                VStack(spacing: 12) {
                    GroupBox(label: Label("Folder & Options", systemImage: "folder")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Folder to scan for .dmg files:")
                                    .font(.caption)
                                Spacer()
                            }
                            HStack {
                                Text(manager.folderPath?.path ?? "No folder selected")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("Choose Folder") { chooseFolder() }
                                    .buttonStyle(.bordered)
                            }

                            Divider()

                            Text("Relative path to run inside each mounted volume:")
                                .font(.caption)
                            TextField("/Path/To/AppOrPkg", text: $relativePath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            HStack {
                                Text("Delay between runs:")
                                    .font(.caption)
                                Stepper(value: $delaySeconds, in: 0...600, step: 1) {
                                    Text("\(Int(delaySeconds)) s")
                                }
                                Spacer()
                                Toggle("Run as admin (prompt)", isOn: $runAsAdmin)
                                    .toggleStyle(.checkbox)
                            }
                        }
                        .padding(8)
                    }

                    GroupBox(label: Label("Script", systemImage: "terminal.fill")) {
                        VStack(alignment: .leading) {
                            TextEditor(text: $manager.customScript)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 140)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))

                            HStack {
                                Button(action: {
                                    Task {
                                        let success = await manager.runScriptOnMounted(delaySeconds: Int(delaySeconds), requireAdmin: runAsAdmin)
                                        if success {
                                            // unmount all when the script succeeded for all mounted DMGs
                                            await manager.unmountAll()
                                        }
                                    }
                                }) {
                                    Label("Run script on mounted DMGs", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.accentColor)

                                Spacer()

                                Button(action: { manager.clearLog() }) {
                                    Label("Clear log", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(8)
                    }

                    Spacer()
                }
                .frame(minWidth: 380)

                // Right panel: list, actions, log
                VStack(spacing: 12) {
                    GroupBox(label: Label("Found DMGs (1 level)", systemImage: "doc.on.doc")) {
                        VStack(alignment: .leading) {
                            List(manager.items) { item in
                                HStack(spacing: 12) {
                                    // colored dot for status
                                    Circle()
                                        .fill(item.isMounted ? Color.green : Color.gray.opacity(0.6))
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline)
                                        Text(item.url.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(item.statusText)
                                        .font(.caption)
                                }
                                .padding(.vertical, 6)
                                .contextMenu {
                                    if item.isMounted {
                                        Button("Open Volume in Finder") {
                                            if let m = item.mountPoint { NSWorkspace.shared.open(URL(fileURLWithPath: m)) }
                                        }
                                    }
                                    Button("Mount Now") {
                                        Task { await manager.mount(item: item) }
                                    }
                                }
                            }
                            .listStyle(.inset)
                            .frame(minHeight: 220)
                        }
                        .padding(4)
                    }

                    HStack {
                        Button(action: { Task { await manager.mountAll() } }) { Text("Mount all") }
                            .buttonStyle(.bordered)
                        Button(action: { Task { await manager.unmountAll() } }) { Text("Unmount all") }
                            .buttonStyle(.bordered)
                        Spacer()
                    }

                    GroupBox(label: Label("Log", systemImage: "doc.plaintext")) {
                        ScrollView {
                            Text(manager.log.joined(separator: "\n"))
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.windowBackgroundColor))
                        }
                        .frame(minHeight: 200)
                    }
                }
                .frame(minWidth: 520)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
        .onAppear { manager.scanForDMGs() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.urls.first {
            manager.folderPath = url
            manager.scanForDMGs()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1100, height: 720)
    }
}

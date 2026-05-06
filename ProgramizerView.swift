import SwiftUI
#if canImport(ProgramizerKit)
import ProgramizerKit
#endif

struct ProgramizerView: View {
    @StateObject private var manager = DMGManager()
    @AppStorage("relativePath") private var relativePath: String = "/Path/To/AppOrPkg"
    @State private var delaySeconds: Double = 2.0
    @State private var runAsAdmin: Bool = false
    // Local saved scripts storage for this view (persisted to UserDefaults)
    struct SavedScript: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var content: String
        init(id: UUID = UUID(), name: String, content: String) { self.id = id; self.name = name; self.content = content }
    }
    @State private var savedScripts: [SavedScript] = []
    @State private var selectedScriptID: UUID? = nil
    @State private var showSaveScriptSheet: Bool = false
    @State private var newScriptName: String = ""

    var body: some View {
        // Reuse the existing Programizer UI here (simplified)
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Programizer")

                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 20)

                    Text("Mass-mount and run processing scripts on DMG volumes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { manager.scanForDMGs() }) { Label("Scan", systemImage: "magnifyingglass") }
                        .buttonStyle(.bordered)
                    Button(action: { Task { await manager.mountAll() } }) { Label("Mount All", systemImage: "externaldrive.badge.plus") }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                }
            }
            .padding(.horizontal)

            HStack(alignment: .top, spacing: 16) {
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
                                Stepper(value: $delaySeconds, in: 0...600, step: 1) { Text("\(Int(delaySeconds)) s") }
                                Spacer()
                                Toggle("Run as admin (prompt)", isOn: $runAsAdmin)
                                    .toggleStyle(.checkbox)
                            }
                        }
                        .padding(8)
                    }

                    GroupBox(label: Label("Script", systemImage: "terminal.fill")) {
                        VStack(alignment: .leading) {
                            // Saved scripts picker and quick actions
                            HStack(spacing: 8) {
                                Picker(selection: $selectedScriptID, label: Text("Saved")) {
                                    Text("(none)").tag(UUID?.none)
                                    ForEach(savedScripts) { s in
                                        Text(s.name).tag(Optional(s.id))
                                    }
                                }
                                .frame(maxWidth: 240)

                                Button("Load") {
                                    if let id = selectedScriptID, let s = savedScripts.first(where: { $0.id == id }) {
                                        manager.customScript = s.content
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(selectedScriptID == nil)

                                Button("Delete") {
                                    if let id = selectedScriptID, let idx = savedScripts.firstIndex(where: { $0.id == id }) {
                                        savedScripts.remove(at: idx)
                                        persistSavedScripts()
                                        selectedScriptID = savedScripts.first?.id
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(selectedScriptID == nil)

                                Spacer()

                                // Import / Export actions
                                Button("Import") {
                                    Task { await importScript() }
                                }
                                .buttonStyle(.bordered)

                                Button("Export") {
                                    Task { await exportScript() }
                                }
                                .buttonStyle(.bordered)

                                Button("Save as…") {
                                    newScriptName = ""
                                    showSaveScriptSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            TextEditor(text: $manager.customScript)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 140)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))

                            HStack {
                                Button(action: {
                                    Task {
                                        await manager.runSequential(relativePath: relativePath, delaySeconds: Int(delaySeconds), requireAdmin: runAsAdmin)
                                    }
                                }) { Label("Run on mounted DMGs", systemImage: "play.fill") }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.accentColor)

                                Spacer()

                                Button(action: { manager.clearLog() }) { Label("Clear log", systemImage: "trash") }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(8)
                    }

                    Spacer()
                }
                .frame(minWidth: 380)

                VStack(spacing: 12) {
                    GroupBox(label: Label("Found DMGs (1 level)", systemImage: "doc.on.doc")) {
                        VStack(alignment: .leading) {
                            List(manager.items) { item in
                                HStack(spacing: 12) {
                                    Circle().fill(item.isMounted ? Color.green : Color.gray.opacity(0.6)).frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).font(.subheadline)
                                        Text(item.url.path).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(item.statusText).font(.caption)
                                }
                                .padding(.vertical, 6)
                                .contextMenu {
                                    if item.isMounted {
                                        Button("Open Volume in Finder") { if let m = item.mountPoint { NSWorkspace.shared.open(URL(fileURLWithPath: m)) } }
                                    }
                                    Button("Mount Now") { Task { await manager.mount(item: item) } }
                                }
                            }
                            .listStyle(.inset)
                            .frame(minHeight: 220)
                        }
                        .padding(4)
                    }

                    HStack {
                        Button(action: { Task { await manager.mountAll() } }) { Text("Mount all") }.buttonStyle(.bordered)
                        Button(action: { Task { await manager.unmountAll() } }) { Text("Unmount all") }.buttonStyle(.bordered)
                        Spacer()
                    }

                    GroupBox(label: Label("Log", systemImage: "doc.plaintext")) {
                        ScrollView { Text(manager.log.joined(separator: "\n")).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(8).background(Color(.windowBackgroundColor)) }
                        .frame(minHeight: 200)
                    }
                }
                .frame(minWidth: 520)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
        .onAppear {
            manager.scanForDMGs()
            // Provide a few starter scripts if none exist
            // load persisted saved scripts for ProgramizerView
            loadSavedScripts()
            if savedScripts.isEmpty {
                savedScripts = [
                    SavedScript(name: "Echo mountpoint", content: "#!/bin/sh\necho \"Mounted at: $MOUNTPOINT\"\nls -la \"$MOUNTPOINT\"") ,
                    SavedScript(name: "List Applications", content: "#!/bin/sh\nif [ -d \"$MOUNTPOINT/Applications\" ]; then ls -la \"$MOUNTPOINT/Applications\"; else echo \"No Applications folder\"; fi"),
                    SavedScript(name: "Install pkg if present", content: "#!/bin/sh\nPKG=\"$MOUNTPOINT/Installer.pkg\"\nif [ -f \"$PKG\" ]; then installer -pkg \"$PKG\" -target /; else echo \"No pkg found\"; fi")
                ]
                persistSavedScripts()
            }
        }
        // Save-as sheet for naming a script
        .sheet(isPresented: $showSaveScriptSheet) {
            VStack(spacing: 12) {
                Text("Save Script As")
                    .font(.headline)
                TextField("Script name", text: $newScriptName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                HStack {
                    Button("Cancel") { showSaveScriptSheet = false }
                    Spacer()
                    Button("Save") {
                        let name = newScriptName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        let content = manager.customScript
                        let s = SavedScript(name: name, content: content)
                        savedScripts.append(s)
                        persistSavedScripts()
                        selectedScriptID = s.id
                        showSaveScriptSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding()
            }
            .padding()
            .frame(width: 480, height: 160)
        }
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

    private func persistSavedScripts() {
        do {
            let data = try JSONEncoder().encode(savedScripts)
            UserDefaults.standard.set(data, forKey: "programizer.savedScripts")
        } catch {
            manager.appendLog("Warning: failed to persist saved scripts: \(error.localizedDescription)")
        }
    }

    private func loadSavedScripts() {
        if let data = UserDefaults.standard.data(forKey: "programizer.savedScripts") {
            do {
                let decoded = try JSONDecoder().decode([SavedScript].self, from: data)
                savedScripts = decoded
            } catch {
                manager.appendLog("Warning: failed to decode saved scripts: \(error.localizedDescription)")
            }
        }
    }

    // Import a script from a text file and load it into the editor. Offer to save as a named script.
    private func importScript() async {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedFileTypes = ["txt", "sh", "bash", "zsh", ""]
            panel.prompt = "Import"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                if let s = String(data: data, encoding: .utf8) {
                    manager.customScript = s
                    manager.appendLog("Imported script from: \(url.path)")

                    // Ask whether to save as a named script
                    let alert = NSAlert()
                    alert.messageText = "Save imported script as a named script?"
                    alert.informativeText = "You can save the imported script for reuse."
                    alert.addButton(withTitle: "Save")
                    alert.addButton(withTitle: "Don't Save")
                    alert.addButton(withTitle: "Cancel")
                    let tf = NSTextField(string: url.deletingPathExtension().lastPathComponent)
                    tf.placeholderString = "Script name"
                    tf.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
                    alert.accessoryView = tf
                    let resp = alert.runModal()
                    if resp == .alertFirstButtonReturn {
                        let name = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            let new = SavedScript(name: name, content: s)
                            savedScripts.append(new)
                            persistSavedScripts()
                            manager.appendLog("Saved imported script as: \(name)")
                        }
                    }
                } else {
                    manager.appendLog("Failed to decode imported file as UTF-8 text: \(url.path)")
                }
            } catch {
                manager.appendLog("Import failed: \(error.localizedDescription)")
            }
        }
    }

    // Export either the currently loaded custom script or a chosen saved script to disk
    private func exportScript() async {
        await MainActor.run {
            // Prefer a saved script if one is selected in the manager; otherwise export current editor content
            let content = manager.customScript
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                manager.appendLog("Nothing to export (script empty).")
                return
            }

            let panel = NSSavePanel()
            panel.nameFieldStringValue = "script.sh"
            panel.allowedFileTypes = ["txt", "sh"]
            panel.canCreateDirectories = true
            panel.prompt = "Export"
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try content.data(using: .utf8)?.write(to: url, options: .atomic)
                    manager.appendLog("Exported script to: \(url.path)")
                } catch {
                    manager.appendLog("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ProgramizerView()
}

import SwiftUI
#if canImport(DMGeniusKit)
import DMGeniusKit
#endif

struct DMGeniusView: View {
    @State private var config = DMGConfiguration()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var createdDMGURL: URL?
    @State private var showLog = false
    @State private var lastCommand = ""
    @State private var lastStdout = ""
    @State private var lastStderr = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DMGs")

                .font(.system(size: 18, weight: .bold))
                .padding(.top, 20)

            AboutDisclosure(description: """
            DMGenius builds macOS disk images (.dmg). Choose a source app or package and an output location, set the volume name and install location, and optionally include an Applications symlink.

            Create a full DMG or a structure-only DMG, then inspect the underlying hdiutil command and its output in the log.
            """)

            HStack {
                Text("Source:")
                if let sourcePath = config.sourceURL?.path {
                    TextField("", text: Binding(get: { sourcePath }, set: { config.sourceURL = URL(fileURLWithPath: $0) }))
                        .lineLimit(1)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text("No file selected").foregroundColor(.secondary)
                }
                Spacer()
                Button("Choose…") { selectSource() }.buttonStyle(.borderedProminent).tint(.blue)
            }

            HStack {
                Text("Output:")
                if let outputPath = config.outputURL?.path {
                    TextField("", text: Binding(get: { outputPath }, set: { config.outputURL = URL(fileURLWithPath: $0) }))
                        .lineLimit(1)
                        .textFieldStyle(.roundedBorder)
                } else { Text("No output chosen").foregroundColor(.secondary) }
                Spacer()
                Button("Choose…") { selectOutput() }.buttonStyle(.borderedProminent).tint(.blue)
            }

            HStack {
                Text("Volume name:")
                TextField("Volume name", text: $config.volumeName).frame(minWidth: 200)
            }

            HStack {
                Text("Install location:")
                Picker("Install location", selection: $config.targetChoice) { ForEach(TargetChoice.allCases) { choice in Text(choice.rawValue).tag(choice) } }
                    .pickerStyle(MenuPickerStyle())
                Spacer()
            }

            Toggle(isOn: $config.includeApplicationsSymlink) { Text("Include Applications symlink") }

            HStack {
                Spacer()
                Button("Create DMG") { createDMG() }.buttonStyle(.borderedProminent).tint(.blue)
                Button("Create Structure DMG") { createStructureOnlyDMG() }.buttonStyle(.bordered).tint(.blue)
            }
            Spacer()

            if !lastCommand.isEmpty || !lastStdout.isEmpty || !lastStderr.isEmpty {
                HStack {
                    Text("Last hdiutil command:")
                    Text(lastCommand).lineLimit(1).foregroundColor(.secondary)
                    Spacer()
                    Button("Show Log") { showLog = true }.buttonStyle(.bordered).tint(.blue)
                }
            }
        }
        .padding()
        .frame(minWidth: 600)
        .alert(isPresented: $showAlert) {
            if let dmgURL = createdDMGURL {
                Alert(title: Text("DMG Creator"), message: Text(alertMessage), primaryButton: .default(Text("Open in Finder")) { NSWorkspace.shared.selectFile(dmgURL.path, inFileViewerRootedAtPath: "") }, secondaryButton: .default(Text("OK")) {})
            } else {
                Alert(title: Text("DMG Creator"), message: Text(alertMessage), primaryButton: .default(Text("Show Log")) { showLog = true }, secondaryButton: .cancel())
            }
        }
        .sheet(isPresented: $showLog) { LogSheet(command: lastCommand, stdout: lastStdout, stderr: lastStderr) }
    }

    private func selectSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first { config.sourceURL = url }
    }

    private func selectOutput() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["dmg"]
        panel.nameFieldStringValue = config.sourceURL?.deletingPathExtension().lastPathComponent.appending(".dmg") ?? "DMGenius.dmg"
        if panel.runModal() == .OK, let url = panel.url { config.outputURL = url }
    }

    private func createDMG() {
        lastCommand = ""
        lastStdout = ""
        lastStderr = ""
        DMGCreator.shared.createDMG(with: config) { result in
            switch result {
            case .success(let url): createdDMGURL = url; alertMessage = "Created DMG at \(url.path)"; showAlert = true
            case .failure(let err): alertMessage = "Failed: \(err.localizedDescription)"; showAlert = true
            }
        }
    }

    private func createStructureOnlyDMG() {
        lastCommand = ""
        lastStdout = ""
        lastStderr = ""
        DMGCreator.shared.createStructureOnlyDMG(with: config) { result in
            switch result {
            case .success(let url): createdDMGURL = url; alertMessage = "Created structure-only DMG at \(url.path)"; showAlert = true
            case .failure(let err): alertMessage = "Failed: \(err.localizedDescription)"; showAlert = true
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
            Text("Command:").bold()
            ScrollView { Text(command).font(.system(.body, design: .monospaced)).padding(4) }.frame(height: 60).textSelection(.enabled)
            Text("Standard Output:").bold()
            ScrollView { Text(stdout.isEmpty ? "(no stdout)" : stdout).font(.system(.body, design: .monospaced)).padding(4) }.frame(minHeight: 100).textSelection(.enabled)
            Text("Standard Error:").bold()
            ScrollView { Text(stderr.isEmpty ? "(no stderr)" : stderr).font(.system(.body, design: .monospaced)).padding(4) }.frame(minHeight: 100).textSelection(.enabled)
            HStack { Spacer(); Button("Close") { dismiss() }.buttonStyle(.borderedProminent).tint(.blue) }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 420)
    }
}

#Preview {
    DMGeniusView()
}

import SwiftUI

struct HelpView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var attributed: AttributedString?
    @State private var rawText: String = ""
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Help")
                    .font(.title)
                    .bold()
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.bottom, 8)

            Divider()

            Group {
                if let attr = attributed {
                    ScrollView {
                        Text(attr)
                            .padding()
                    }
                } else if !rawText.isEmpty {
                    ScrollView {
                        Text(rawText)
                            .padding()
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                    }
                } else if let err = loadError {
                    Text(err)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ProgressView("Loading…")
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onAppear(perform: loadExample)
    }

    private func loadExample() {
        // Try several locations for EXAMPLE.md: bundle resource, executable sibling, current directory
        if let url = Bundle.main.url(forResource: "EXAMPLE", withExtension: "md") {
            load(from: url)
            return
        }

        // Try executable directory
        if let exe = Bundle.main.executableURL {
            let candidate = exe.deletingLastPathComponent().appendingPathComponent("EXAMPLE.md")
            if FileManager.default.fileExists(atPath: candidate.path) {
                load(from: candidate)
                return
            }
        }

        // Try main bundle URL parent (for when running from Xcode)
        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        let candidate2 = bundleParent.appendingPathComponent("EXAMPLE.md")
        if FileManager.default.fileExists(atPath: candidate2.path) {
            load(from: candidate2)
            return
        }

        // Try current working directory
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidate3 = cwd.appendingPathComponent("EXAMPLE.md")
        if FileManager.default.fileExists(atPath: candidate3.path) {
            load(from: candidate3)
            return
        }

        loadError = "EXAMPLE.md not found in bundle or expected fallback locations."
    }

    private func load(from url: URL) {
        do {
            let str = try String(contentsOf: url)
            do {
                attributed = try AttributedString(markdown: str)
            } catch {
                rawText = str
                loadError = "Failed to parse markdown; showing raw text. (\(error.localizedDescription))"
            }
        } catch {
            loadError = "Failed to load EXAMPLE.md: \(error.localizedDescription)"
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}

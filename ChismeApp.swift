//
//  ChismeApp.swift
//  Chisme
//
//  A macOS app for managing files between source and target folders
//

import SwiftUI

final class AppState: ObservableObject {
    @Published var showingHelp: Bool = false
}

@main
struct ChismeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("Show Help") {
                    appState.showingHelp = true
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }
}

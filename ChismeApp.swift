//
//  ChismeApp.swift
//  Chisme
//
//  A macOS app for managing files between source and target folders
//

import SwiftUI

@main
struct ChismeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

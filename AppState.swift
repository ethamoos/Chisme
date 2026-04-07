
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var showingHelp: Bool = false
}

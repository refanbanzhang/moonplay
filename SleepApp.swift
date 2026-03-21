import SwiftUI

enum AppWindow {
    static let width: CGFloat = 340
    static let height: CGFloat = 520
}

@main
struct SleepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: AppWindow.width, height: AppWindow.height)
    }
}

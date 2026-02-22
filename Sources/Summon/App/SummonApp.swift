import SwiftUI

@main
struct SummonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window is managed manually by AppDelegate via NSWindow.
        // A dummy Settings scene is kept because SwiftUI requires at least one Scene.
        Settings {
            EmptyView()
        }
    }
}

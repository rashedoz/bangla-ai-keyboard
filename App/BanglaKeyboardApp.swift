import SwiftUI

@main
struct BanglaKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                SetupView()
                    .tabItem { Label("Setup", systemImage: "keyboard") }
                PlaygroundView()
                    .tabItem { Label("Try it", systemImage: "text.cursor") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
    }
}

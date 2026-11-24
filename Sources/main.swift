import SwiftUI
import AppKit

@main
struct MusicMixStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Audio") {
                Button("Add Audio Files...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenFilesTrigger"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Export Merged Audio...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportTrigger"), object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            CommandMenu("Playback") {
                Button("Play / Pause") {
                    NotificationCenter.default.post(name: NSNotification.Name("PlayPauseTrigger"), object: nil)
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Rewind to Beginning") {
                    NotificationCenter.default.post(name: NSNotification.Name("RewindTrigger"), object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

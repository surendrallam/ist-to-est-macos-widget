import AppKit
import SwiftUI
import WidgetKit

@main
struct ISTtoESTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("IST to EST", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Link("IST to EST on GitHub", destination: AppLinks.repository)
                Link("Report an Issue", destination: AppLinks.issues)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launching the app registers the widget with the system; reloading
        // also refreshes widgets that are already placed after an update.
        WidgetCenter.shared.reloadAllTimelines()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

enum AppLinks {
    // swiftlint:disable force_unwrapping
    static let repository = URL(string: "https://github.com/surendrallam/ist-to-est-macos-widget")!
    static let issues = URL(string: "https://github.com/surendrallam/ist-to-est-macos-widget/issues")!
    static let website = URL(string: "https://surendrallam.github.io/ist-to-est-macos-widget/")!
    // swiftlint:enable force_unwrapping
}

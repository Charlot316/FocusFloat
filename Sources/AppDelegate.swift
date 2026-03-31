import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let remindersStore = RemindersStore()
    private var floatingPanelController: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let rootView = OverlayRootView(store: remindersStore)
        floatingPanelController = FloatingPanelController(rootView: rootView)
        floatingPanelController?.showWindow(nil)
        floatingPanelController?.window?.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)

        Task {
            await remindersStore.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

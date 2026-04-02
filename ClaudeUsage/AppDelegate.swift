import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var usageStore = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
        Task { @MainActor in
            await usageStore.loadCredentials()
            statusBarController.updateTitle(usageStore.menuBarTitle)
        }
    }
}

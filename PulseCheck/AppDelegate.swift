import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var usageStore = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
        statusBarController.setStore(usageStore)
        usageStore.onTitleChanged = { [weak self] title in
            self?.statusBarController.updateTitle(title)
        }
        Task { @MainActor in
            await usageStore.loadCredentials()
            statusBarController.updateTitle(usageStore.menuBarTitle)

            // Only fetch if we have credentials
            if usageStore.credentials != nil {
                await usageStore.fetchUsage()
            }
            usageStore.startPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageStore.stopPolling()
    }
}

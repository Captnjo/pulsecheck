import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var usageStore = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
        statusBarController.setStore(usageStore)
        Task { @MainActor in
            await usageStore.loadCredentials()

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

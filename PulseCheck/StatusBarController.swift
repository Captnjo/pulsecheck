import AppKit
import SwiftUI

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()
        popover.behavior = .transient

        if let button = statusItem.button {
            button.title = "—%"
            let icon = NSImage(named: "PulseCheckIcon")
            icon?.isTemplate = true
            button.image = icon
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp])
        }
    }

    func updateTitle(_ text: String) {
        statusItem.button?.title = text
    }

    func setStore(_ store: UsageStore) {
        let panelView = UsagePanelView(store: store)
        let hosting = NSHostingController(rootView: panelView)
        hosting.view.frame.size = CGSize(width: 280, height: hosting.sizeThatFits(in: CGSize(width: 280, height: 1000)).height)
        popover.contentViewController = hosting
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

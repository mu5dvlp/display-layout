import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var arrangementVC: ArrangementViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let iconName = "display.2"
            let fallback = "rectangle.on.rectangle"
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ディスプレイ配置") ??
                        NSImage(systemSymbolName: fallback, accessibilityDescription: "ディスプレイ配置")
            button.image = image
            button.action = #selector(handleButtonClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        arrangementVC = ArrangementViewController()

        popover = NSPopover()
        popover.contentViewController = arrangementVC
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 300)
    }

    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                arrangementVC.reload()
                if let button = statusItem.button {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
}

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var downloadManager: DownloadManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        downloadManager = DownloadManager()
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note",
                                   accessibilityDescription: "Soulseeker")
            button.action = #selector(togglePanel)
            button.target = self
        }

        panel = FloatingPanel()
        let content = NSHostingView(rootView: ContentView(downloadManager: downloadManager))
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(content)
        if let cv = panel.contentView {
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: cv.topAnchor),
                content.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
            ])
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            let buttonFrame = buttonWindow.convertToScreen(
                button.convert(button.bounds, to: nil))
            let x = buttonFrame.midX - panel.frame.width / 2
            let y = buttonFrame.minY - panel.frame.height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        panel.orderOut(nil)
    }
}

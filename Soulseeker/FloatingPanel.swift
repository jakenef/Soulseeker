import AppKit

class FloatingPanel: NSPanel {
    init(width: CGFloat = 380, height: CGFloat = 500) {
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        let blur = NSVisualEffectView()
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.material = .hudWindow
        contentView = blur
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

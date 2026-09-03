import AppKit

final class HUD {
    static let shared = HUD()

    private var panel: NSPanel?
    private var label: NSTextField?
    private var hideWork: DispatchWorkItem?

    func show(_ text: String, duration: TimeInterval = 1.6) {
        DispatchQueue.main.async {
            self.showOnMain(text, duration: duration)
        }
    }

    func hide() {
        hideWork?.cancel()
        panel?.orderOut(nil)
    }

    private func showOnMain(_ text: String, duration: TimeInterval) {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 36),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .statusBar
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

            let background = NSView(frame: panel.contentView!.bounds)
            background.wantsLayer = true
            background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
            background.layer?.cornerRadius = 8
            background.autoresizingMask = [.width, .height]

            let label = NSTextField(labelWithString: text)
            label.textColor = .white
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.alignment = .center
            label.frame = background.bounds.insetBy(dx: 10, dy: 8)
            label.autoresizingMask = [.width, .height]
            background.addSubview(label)
            panel.contentView = background

            self.panel = panel
            self.label = label
        }

        label?.stringValue = text
        position()
        panel?.orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func position() {
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let width = max(160, label?.intrinsicContentSize.width ?? 160) + 28
        let height: CGFloat = 36
        let x = screen.frame.midX - width / 2
        let y = screen.frame.minY + 80
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

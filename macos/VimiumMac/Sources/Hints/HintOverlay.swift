import AppKit

/// Per-screen borderless NSPanel overlay that ignores the mouse and joins all Spaces.
final class HintOverlay {
    private var panels: [HintPanel] = []

    func show(markers: [HintEngine.Marker], typed: String) {
        hide()
        for screen in NSScreen.screens {
            let panel = HintPanel(screen: screen)
            panel.render(markers: markers, typed: typed, screen: screen)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func update(markers: [HintEngine.Marker], typed: String) {
        if panels.count != NSScreen.screens.count {
            show(markers: markers, typed: typed)
            return
        }
        for (panel, screen) in zip(panels, NSScreen.screens) {
            panel.render(markers: markers, typed: typed, screen: screen)
        }
    }

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }
}

private final class HintPanel: NSPanel {
    private let hintView = HintCanvasView()

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        becomesKeyOnlyIfNeeded = true
        contentView = hintView
        setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func render(markers: [HintEngine.Marker], typed: String, screen: NSScreen) {
        hintView.screenFrame = screen.frame
        hintView.typed = typed
        hintView.markers = markers.filter { marker in
            AXSupport.axRectToCocoa(marker.target.frame).intersects(screen.frame)
        }
        hintView.needsDisplay = true
    }
}

private final class HintCanvasView: NSView {
    var markers: [HintEngine.Marker] = []
    var typed = ""
    var screenFrame: CGRect = .zero

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let window else { return }

        for marker in markers {
            let cocoa = AXSupport.axRectToCocoa(marker.target.frame)
            var viewRect = window.convertFromScreen(cocoa)
            viewRect = convert(viewRect, from: nil)

            let label = marker.hintString.uppercased()
            let typedCount = min(typed.count, label.count)
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
            ]
            let size = (label as NSString).size(withAttributes: attrs)
            let padding = NSSize(width: 5, height: 3)
            let box = CGRect(
                x: viewRect.minX,
                y: viewRect.maxY - size.height - padding.height * 2,
                width: size.width + padding.width * 2,
                height: size.height + padding.height * 2
            )

            NSColor(calibratedRed: 1, green: 0.85, blue: 0.2, alpha: 0.95).setFill()
            NSColor.black.withAlphaComponent(0.55).setStroke()
            let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            path.fill()
            path.lineWidth = 1
            path.stroke()

            let textOrigin = CGPoint(x: box.minX + padding.width, y: box.minY + padding.height - 1)
            if typedCount == 0 {
                (label as NSString).draw(at: textOrigin, withAttributes: attrs)
            } else {
                let typedPart = String(label.prefix(typedCount))
                let rest = String(label.dropFirst(typedCount))
                let typedAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.45, blue: 0.15, alpha: 1),
                ]
                (typedPart as NSString).draw(at: textOrigin, withAttributes: typedAttrs)
                let typedSize = (typedPart as NSString).size(withAttributes: typedAttrs)
                (rest as NSString).draw(
                    at: CGPoint(x: textOrigin.x + typedSize.width, y: textOrigin.y),
                    withAttributes: attrs
                )
            }
        }
    }
}

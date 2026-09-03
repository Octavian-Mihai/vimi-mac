import AppKit
import Carbon.HIToolbox
import CoreGraphics

enum Actions {
    /// Comfortable line-ish distance in pixels (smooth, not one jumpy tick).
    static let lineDistance: Double = 96
    static let lineDuration: TimeInterval = 0.18
    static let pageDuration: TimeInterval = 0.22

    static func perform(_ command: Command, count: Int) {
        let n = max(1, count)
        let scale = Double(n)
        switch command {
        case .scrollDown:
            SmoothScroller.shared.animate(dx: 0, dy: -lineDistance * scale, duration: lineDuration)
        case .scrollUp:
            SmoothScroller.shared.animate(dx: 0, dy: lineDistance * scale, duration: lineDuration)
        case .scrollLeft:
            SmoothScroller.shared.animate(dx: lineDistance * scale, dy: 0, duration: lineDuration)
        case .scrollRight:
            SmoothScroller.shared.animate(dx: -lineDistance * scale, dy: 0, duration: lineDuration)
        case .scrollPageDown:
            SmoothScroller.shared.animate(dx: 0, dy: -pageHeight() * 0.48 * scale, duration: pageDuration)
        case .scrollPageUp:
            SmoothScroller.shared.animate(dx: 0, dy: pageHeight() * 0.48 * scale, duration: pageDuration)
        case .scrollFullPageDown:
            SmoothScroller.shared.animate(dx: 0, dy: -pageHeight() * 0.92 * scale, duration: pageDuration)
        case .scrollFullPageUp:
            SmoothScroller.shared.animate(dx: 0, dy: pageHeight() * 0.92 * scale, duration: pageDuration)
        case .scrollToTop:
            SmoothScroller.shared.cancel()
            postKey(CGKeyCode(kVK_UpArrow), flags: .maskCommand)
        case .scrollToBottom:
            SmoothScroller.shared.cancel()
            postKey(CGKeyCode(kVK_DownArrow), flags: .maskCommand)
        case .goBack:
            postKey(CGKeyCode(kVK_ANSI_LeftBracket), flags: .maskCommand)
        case .goForward:
            postKey(CGKeyCode(kVK_ANSI_RightBracket), flags: .maskCommand)
        case .reload:
            postKey(CGKeyCode(kVK_ANSI_R), flags: .maskCommand)
        case .enterInsertMode, .activateHints, .activateHintsNewTab, .activateHintsCopyLink:
            break
        }
    }

    /// One pixel-unit wheel event at the focused window. Prefer this over line ticks.
    static func postPixelScroll(dx: Int32, dy: Int32) {
        guard dx != 0 || dy != 0 else { return }
        let location = focusedWindowCenter() ?? NSEvent.mouseLocation.quartz
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else { return }
        event.location = location
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(dy))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(dx))
        event.post(tap: .cghidEventTap)
    }

    static func click(at quartzPoint: CGPoint, command: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        for type: CGEventType in [.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: quartzPoint,
                mouseButton: .left
            ) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    static func activate(target: HintTarget, action: HintAction) {
        switch action {
        case .click:
            if AXSupport.press(target.element) { return }
            click(at: target.quartzCenter, command: false)
        case .commandClick:
            click(at: target.quartzCenter, command: true)
        case .copyLink:
            let text = target.copyText
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            HUD.shared.show("Yanked \(truncate(text))")
        }
    }

    static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func focusedWindowCenter() -> CGPoint? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        guard let window = AXSupport.focusedWindow(pid: app.processIdentifier),
              let frame = AXSupport.frame(window) else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    static func pageHeight() -> Double {
        if let app = NSWorkspace.shared.frontmostApplication,
           let window = AXSupport.focusedWindow(pid: app.processIdentifier),
           let frame = AXSupport.frame(window) {
            return max(240, Double(frame.height))
        }
        if let screen = NSScreen.main {
            return max(240, Double(screen.visibleFrame.height))
        }
        return 800
    }

    private static func truncate(_ text: String) -> String {
        if text.count <= 48 { return text }
        let idx = text.index(text.startIndex, offsetBy: 45)
        return String(text[..<idx]) + "…"
    }
}

/// Short ease-out burst of pixel-wheel events. Caps at ~250ms so it never spins the CPU.
final class SmoothScroller {
    static let shared = SmoothScroller()

    private var timer: Timer?
    private var startTime: TimeInterval = 0
    private var duration: TimeInterval = 0.2
    private var totalX: Double = 0
    private var totalY: Double = 0
    private var postedX: Double = 0
    private var postedY: Double = 0

    func animate(dx: Double, dy: Double, duration: TimeInterval) {
        if timer != nil {
            totalX = (totalX - postedX) + dx
            totalY = (totalY - postedY) + dy
        } else {
            totalX = dx
            totalY = dy
        }
        postedX = 0
        postedY = 0
        self.duration = min(max(duration, 0.15), 0.25)
        startTime = ProcessInfo.processInfo.systemUptime

        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        tick()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        totalX = 0
        totalY = 0
        postedX = 0
        postedY = 0
    }

    private func tick() {
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let t = min(1.0, elapsed / duration)
        let eased = 1 - pow(1 - t, 3)
        let targetX = totalX * eased
        let targetY = totalY * eased
        let ix = Int32((targetX - postedX).rounded())
        let iy = Int32((targetY - postedY).rounded())
        if ix != 0 || iy != 0 {
            Actions.postPixelScroll(dx: ix, dy: iy)
            postedX += Double(ix)
            postedY += Double(iy)
        }
        if t >= 1 {
            let rx = Int32((totalX - postedX).rounded())
            let ry = Int32((totalY - postedY).rounded())
            if rx != 0 || ry != 0 {
                Actions.postPixelScroll(dx: rx, dy: ry)
            }
            cancel()
        }
    }
}

private extension NSPoint {
    var quartz: CGPoint {
        AXSupport.cocoaPointToAX(self)
    }
}

import AppKit
import ApplicationServices

/// Polls / observes the focused AX element and reports whether it is a text field.
final class FocusWatcher {
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var enhancedPID: pid_t = 0

    private(set) var isTextInputFocused = false
    private(set) var focusedPID: pid_t = 0

    var onChange: (() -> Void)?

    func start() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
        observer = nil
    }

    func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            update(isText: false, pid: 0)
            return
        }
        let pid = app.processIdentifier
        if pid != enhancedPID {
            enhancedPID = pid
            AXSupport.enableEnhancedAccessibility(pid: pid)
        }
        attachObserver(pid: pid)

        guard let focused = AXSupport.focusedElement(pid: pid) else {
            update(isText: false, pid: pid)
            return
        }
        update(isText: AXSupport.isTextInput(focused), pid: pid)
    }

    private func update(isText: Bool, pid: pid_t) {
        let changed = isText != isTextInputFocused || pid != focusedPID
        isTextInputFocused = isText
        focusedPID = pid
        if changed {
            onChange?()
        }
    }

    private func attachObserver(pid: pid_t) {
        guard pid != observedPID, pid != 0 else { return }
        observedPID = pid
        observer = nil

        var newObserver: AXObserver?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            let watcher = Unmanaged<FocusWatcher>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                watcher.refresh()
            }
        }, &newObserver)
        guard status == .success, let newObserver else { return }

        let app = AXSupport.application(pid: pid)
        AXObserverAddNotification(newObserver, app, kAXFocusedUIElementChangedNotification as CFString, selfPtr)
        AXObserverAddNotification(newObserver, app, kAXFocusedWindowChangedNotification as CFString, selfPtr)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        observer = newObserver
    }
}

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Coordinates modes, the event tap, scrolling, hints, and per-app exclusions.
final class VimiumEngine {
    let exclusions = AppExclusions.shared
    let keyMapper = KeyMapper()
    let focusWatcher = FocusWatcher()
    let eventTap = EventTap()
    let hintEngine = HintEngine()
    let overlay = HintOverlay()

    private(set) var mode: VimiumMode = .normal
    private var forcedNormal = false
    private var lastTextFocus = false
    private var swallowedKeyCodes = Set<Int64>()
    private var permissionTimer: Timer?
    private var didStartTap = false
    private(set) var tapStartFailed = false
    private(set) var tapFailureMessage: String?

    func start() {
        focusWatcher.onChange = { [weak self] in
            self?.handleFocusChange()
        }
        eventTap.handler = { [weak self] type, event in
            self?.handleEvent(type: type, event: event) ?? .pass
        }

        focusWatcher.start()
        tryStartTap()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.tryStartTap()
        }
        NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
    }

    func stop() {
        permissionTimer?.invalidate()
        eventTap.stop()
        focusWatcher.stop()
        overlay.hide()
        HUD.shared.hide()
        SmoothScroller.shared.cancel()
    }

    var isTapRunning: Bool { eventTap.isRunning }

    func retryKeyboardTap() {
        tapStartFailed = false
        tapFailureMessage = nil
        tryStartTap()
        NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
    }

    func togglePaused() {
        exclusions.togglePaused()
        if exclusions.isPaused {
            exitHints()
            HUD.shared.show("Vimium paused")
        } else {
            HUD.shared.show("Vimium resumed")
        }
        NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
    }

    func toggleCurrentApp() {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        exclusions.toggle(bundleID: id)
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? id
        let enabled = exclusions.isEnabled(bundleID: id)
        HUD.shared.show(enabled ? "Enabled for \(name)" : "Disabled for \(name)")
    }

    private func tryStartTap() {
        if eventTap.isRunning {
            if tapStartFailed {
                tapStartFailed = false
                tapFailureMessage = nil
                NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
            }
            if !didStartTap {
                didStartTap = true
                NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
            }
            return
        }
        guard PermissionManager.isTrusted() else { return }
        if eventTap.start() {
            didStartTap = true
            tapStartFailed = false
            tapFailureMessage = nil
            HUD.shared.show("Vimium Mac ready")
            NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
        } else if !tapStartFailed {
            tapStartFailed = true
            tapFailureMessage = "Accessibility is on, but the global key tap could not start. Enable Vimium Mac under Privacy & Security → Input Monitoring as well, then click Retry."
            NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
        }
    }

    private func handleFocusChange() {
        if let app = NSWorkspace.shared.frontmostApplication {
            AXSupport.enableEnhancedAccessibility(pid: app.processIdentifier)
        }

        let isText = focusWatcher.isTextInputFocused
        if isText != lastTextFocus {
            forcedNormal = false
        }
        lastTextFocus = isText

        if mode == .hint { return }

        if isText && !forcedNormal {
            setMode(.insert)
        } else if mode == .insert && !isText {
            setMode(.normal)
        }
    }

    private func setMode(_ newMode: VimiumMode) {
        guard mode != newMode else { return }
        mode = newMode
        NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> KeyOutcome {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyUp {
            if swallowedKeyCodes.remove(keyCode) != nil {
                return .swallow
            }
            return .pass
        }

        guard type == .keyDown else { return .pass }

        if isPauseHotkey(event) {
            togglePaused()
            swallow(keyCode)
            return .swallow
        }

        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)

        if hasCommand || hasControl || hasOption {
            return .pass
        }

        if exclusions.isPaused {
            return .pass
        }

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if bundleID == Bundle.main.bundleIdentifier {
            return .pass
        }
        if !exclusions.isEnabled(bundleID: bundleID) {
            return .pass
        }

        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 && mode == .hint {
            swallow(keyCode)
            return .swallow
        }

        if isEscape(event) {
            return handleEscape(keyCode: keyCode)
        }

        if mode == .hint {
            return handleHintKey(event, keyCode: keyCode)
        }

        let effectiveInsert = (mode == .insert) || (focusWatcher.isTextInputFocused && !forcedNormal && mode != .hint)
        if effectiveInsert {
            return .pass
        }

        guard let keyChar = keyCharacter(from: event), !keyChar.isEmpty else {
            return .pass
        }

        switch keyMapper.handle(keyChar: keyChar) {
        case .pass:
            return .pass
        case .consumed:
            swallow(keyCode)
            return .swallow
        case .command(let command, let count):
            swallow(keyCode)
            DispatchQueue.main.async {
                self.run(command, count: count)
            }
            return .swallow
        }
    }

    private func handleEscape(keyCode: Int64) -> KeyOutcome {
        if mode == .hint {
            exitHints()
            swallow(keyCode)
            return .swallow
        }
        if !keyMapper.isInResetState {
            keyMapper.reset()
            swallow(keyCode)
            return .swallow
        }
        if mode == .insert || (focusWatcher.isTextInputFocused && !forcedNormal) {
            forcedNormal = true
            setMode(.normal)
            HUD.shared.show("Normal mode")
            swallow(keyCode)
            return .swallow
        }
        return .pass
    }

    private func handleHintKey(_ event: CGEvent, keyCode: Int64) -> KeyOutcome {
        if keyCode == Int64(kVK_Delete) {
            switch hintEngine.pop() {
            case .cancel:
                exitHints()
            case .updated:
                overlay.update(markers: hintEngine.visible, typed: hintEngine.typed)
            case .activate:
                break
            }
            swallow(keyCode)
            return .swallow
        }

        guard let keyChar = keyCharacter(from: event)?.lowercased(), !keyChar.isEmpty else {
            swallow(keyCode)
            return .swallow
        }

        switch hintEngine.push(keyChar) {
        case .updated:
            overlay.update(markers: hintEngine.visible, typed: hintEngine.typed)
        case .cancel:
            exitHints()
        case .activate(let target):
            let action = hintEngine.action
            exitHints()
            DispatchQueue.main.async {
                Actions.activate(target: target, action: action)
            }
        }
        swallow(keyCode)
        return .swallow
    }

    private func run(_ command: Command, count: Int) {
        switch command {
        case .enterInsertMode:
            forcedNormal = false
            setMode(.insert)
            HUD.shared.show("Insert mode")
        case .activateHints:
            beginHints(.click)
        case .activateHintsNewTab:
            beginHints(.commandClick)
        case .activateHintsCopyLink:
            beginHints(.copyLink)
        default:
            Actions.perform(command, count: count)
        }
    }

    private func beginHints(_ action: HintAction) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        AXSupport.enableEnhancedAccessibility(pid: app.processIdentifier)
        let targets = ElementCollector.collect(pid: app.processIdentifier)
        guard !targets.isEmpty else {
            HUD.shared.show("No clickable elements")
            return
        }
        hintEngine.start(targets: targets, action: action)
        overlay.show(markers: hintEngine.visible, typed: "")
        setMode(.hint)
        let label: String
        switch action {
        case .click: label = "Hint mode"
        case .commandClick: label = "Hint mode (⌘-click)"
        case .copyLink: label = "Hint mode (yank)"
        }
        HUD.shared.show(label)
    }

    private func exitHints() {
        hintEngine.reset()
        overlay.hide()
        if mode == .hint {
            if focusWatcher.isTextInputFocused && !forcedNormal {
                setMode(.insert)
            } else {
                setMode(.normal)
            }
        }
    }

    private func swallow(_ keyCode: Int64) {
        swallowedKeyCodes.insert(keyCode)
    }

    private func isPauseHotkey(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        return keyCode == Int64(kVK_ANSI_V)
            && flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && flags.contains(.maskShift)
            && !flags.contains(.maskCommand)
    }

    private func isEscape(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape)
    }

    private func keyCharacter(from event: CGEvent) -> String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        let raw = String(utf16CodeUnits: buffer, count: Int(length))
        return raw == "\u{1B}" ? nil : raw
    }
}

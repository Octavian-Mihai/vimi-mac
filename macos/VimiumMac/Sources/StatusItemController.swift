import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private let engine: VimiumEngine
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var observer: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?

    init(engine: VimiumEngine) {
        self.engine = engine
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = Self.menuImage(paused: engine.exclusions.isPaused)
            button.imagePosition = .imageOnly
            button.toolTip = "Vimium Mac"
        }

        menu.delegate = self
        statusItem.menu = menu

        observer = NotificationCenter.default.addObserver(
            forName: .vimiumStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshButton()
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshButton()
        }
        refreshButton()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let windowVisible = (NSApp.delegate as? AppDelegate)?.isMainWindowVisible() == true
        let showItem = NSMenuItem(
            title: windowVisible ? "Hide Window" : "Show Window",
            action: #selector(toggleMainWindow),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

        let app = NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "this app"
        let bundleID = app?.bundleIdentifier
        let enabled = engine.exclusions.isEnabled(bundleID: bundleID)

        let appItem = NSMenuItem(
            title: enabled ? "Disable for \(name)" : "Enable for \(name)",
            action: #selector(toggleApp),
            keyEquivalent: ""
        )
        appItem.target = self
        appItem.isEnabled = bundleID != nil && bundleID != Bundle.main.bundleIdentifier
        menu.addItem(appItem)

        let pauseItem = NSMenuItem(
            title: engine.exclusions.isPaused ? "Resume Vimium Mac" : "Pause Vimium Mac",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let hotkeyHint = NSMenuItem(
            title: "Global pause hotkey: ⌃⌥⇧V",
            action: nil,
            keyEquivalent: ""
        )
        hotkeyHint.isEnabled = false
        menu.addItem(hotkeyHint)

        menu.addItem(.separator())

        let modeItem = NSMenuItem(
            title: modeTitle(),
            action: nil,
            keyEquivalent: ""
        )
        modeItem.isEnabled = false
        menu.addItem(modeItem)

        let trustItem = NSMenuItem(
            title: PermissionManager.isTrusted()
                ? "Accessibility: granted"
                : "Accessibility: not granted",
            action: nil,
            keyEquivalent: ""
        )
        trustItem.isEnabled = false
        menu.addItem(trustItem)

        if !PermissionManager.isTrusted() || !engine.isTapRunning {
            let openItem = NSMenuItem(
                title: "Open Accessibility Settings…",
                action: #selector(openSettings),
                keyEquivalent: ""
            )
            openItem.target = self
            menu.addItem(openItem)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Vimium Mac",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    private func modeTitle() -> String {
        if engine.exclusions.isPaused { return "Mode: paused" }
        let appEnabled = engine.exclusions.isEnabled(
            bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
        if !appEnabled { return "Mode: disabled in this app" }
        switch engine.mode {
        case .normal: return "Mode: normal"
        case .insert: return "Mode: insert"
        case .hint: return "Mode: hint"
        }
    }

    private func refreshButton() {
        statusItem.button?.image = Self.menuImage(paused: engine.exclusions.isPaused)
        statusItem.button?.appearsDisabled = engine.exclusions.isPaused || !PermissionManager.isTrusted()
    }

    @objc private func toggleMainWindow() {
        (NSApp.delegate as? AppDelegate)?.toggleMainWindow()
    }

    @objc private func toggleApp() {
        engine.toggleCurrentApp()
    }

    @objc private func togglePause() {
        engine.togglePaused()
    }

    @objc private func toggleLogin() {
        let next = !LaunchAtLogin.isEnabled
        if let error = LaunchAtLogin.setEnabled(next) {
            let alert = NSAlert()
            alert.messageText = "Could not update Login Items"
            alert.informativeText = error + "\n\nMove Vimium Mac to /Applications and try again."
            alert.runModal()
        }
    }

    @objc private func openSettings() {
        PermissionManager.promptIfNeeded()
        PermissionManager.openAccessibilitySettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func menuImage(paused: Bool) -> NSImage? {
        let name = paused ? "pause.circle" : "keyboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Vimium Mac")
        image?.isTemplate = true
        return image
    }
}

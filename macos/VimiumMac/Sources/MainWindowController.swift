import AppKit

final class MainWindowController: NSWindowController {
    private let engine: VimiumEngine

    private let iconView = NSImageView()
    private let statusDot = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let openSettingsButton = NSButton()
    private let retryButton = NSButton()
    private let pauseButton = NSButton()
    private let loginButton = NSButton()
    private var observer: NSObjectProtocol?
    private var refreshTimer: Timer?

    init(engine: VimiumEngine) {
        self.engine = engine
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vimium Mac"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.contentView = buildContent()
        refresh()

        observer = NotificationCenter.default.addObserver(
            forName: .vimiumStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        refreshTimer?.invalidate()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func buildContent() -> NSView {
        let root = NSView()

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        iconView.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Vimium Mac")
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
        ])

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        let title = NSTextField(labelWithString: "Vimium Mac")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Keyboard navigation for every Mac app")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(subtitle)
        header.addArrangedSubview(iconView)
        header.addArrangedSubview(titleStack)

        let statusCard = NSView()
        statusCard.wantsLayer = true
        statusCard.layer?.cornerRadius = 10
        statusCard.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        statusCard.translatesAutoresizingMaskIntoConstraints = false

        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),
        ])

        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let statusRow = NSStackView(views: [statusDot, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor

        let statusStack = NSStackView(views: [statusRow, detailLabel])
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 6
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 12),
            statusStack.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 14),
            statusStack.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -14),
            statusStack.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -12),
        ])

        openSettingsButton.title = "Open Accessibility Settings"
        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.controlSize = .large
        openSettingsButton.font = .systemFont(ofSize: 14, weight: .semibold)
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openAccessibilitySettings)
        openSettingsButton.setButtonType(.momentaryPushIn)
        openSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        openSettingsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true

        retryButton.title = "Retry Keyboard Tap"
        retryButton.bezelStyle = .rounded
        retryButton.target = self
        retryButton.action = #selector(retryTap)

        let cheatTitle = NSTextField(labelWithString: "Keybindings")
        cheatTitle.font = .systemFont(ofSize: 13, weight: .semibold)

        let cheat = cheatSheet()

        let footnote = NSTextField(wrappingLabelWithString: "Close this window anytime — Vimium Mac stays in the menu bar. Click the keyboard extra (or choose Show Window) to bring it back. Keys are ignored in this app and in terminals/editors by default. Safari, Firefox, Chrome, Discord, and other browsers are on — toggle any app from the menu bar.")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor

        pauseButton.setButtonType(.switch)
        pauseButton.title = "Pause Vimium Mac"
        pauseButton.target = self
        pauseButton.action = #selector(togglePause)

        loginButton.setButtonType(.switch)
        loginButton.title = "Launch at login"
        loginButton.target = self
        loginButton.action = #selector(toggleLogin)

        let quitButton = NSButton(title: "Quit Vimium Mac", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded

        let bottomRow = NSStackView(views: [pauseButton, loginButton])
        bottomRow.orientation = .vertical
        bottomRow.alignment = .leading
        bottomRow.spacing = 8

        let stack = NSStackView(views: [
            header,
            statusCard,
            openSettingsButton,
            retryButton,
            cheatTitle,
            cheat,
            bottomRow,
            quitButton,
            footnote,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(18, after: header)
        stack.setCustomSpacing(10, after: openSettingsButton)
        stack.setCustomSpacing(18, after: retryButton)
        stack.setCustomSpacing(6, after: cheatTitle)
        stack.setCustomSpacing(16, after: cheat)
        stack.setCustomSpacing(16, after: bottomRow)

        openSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        cheat.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20),
            openSettingsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            retryButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            cheat.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        return root
    }

    private func cheatSheet() -> NSView {
        let rows: [(String, String)] = [
            ("h j k l", "Smooth scroll left / down / up / right"),
            ("J / K", "Full page down / up"),
            ("d / u", "Half-page down / up"),
            ("gg / G", "Top / bottom"),
            ("f", "Hint mode — click a link or button"),
            ("F", "Hint mode — ⌘-click"),
            ("yf", "Hint mode — copy URL / title"),
            ("H / L", "History back / forward"),
            ("i / Esc", "Insert mode / back to normal"),
        ]
        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 6
        for (keys, meaning) in rows {
            let keyLabel = NSTextField(labelWithString: keys)
            keyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            keyLabel.setContentHuggingPriority(.required, for: .horizontal)
            keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            keyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

            let meaningLabel = NSTextField(labelWithString: meaning)
            meaningLabel.font = .systemFont(ofSize: 12)
            meaningLabel.textColor = .secondaryLabelColor

            let row = NSStackView(views: [keyLabel, meaningLabel])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 12
            grid.addArrangedSubview(row)
        }
        return grid
    }

    private func refresh() {
        let trusted = PermissionManager.isTrusted()
        let tapRunning = engine.isTapRunning
        let paused = engine.exclusions.isPaused
        pauseButton.state = paused ? .on : .off
        loginButton.state = LaunchAtLogin.isEnabled ? .on : .off

        if !trusted {
            statusLabel.stringValue = "Accessibility is not granted"
            detailLabel.stringValue = "Enable Vimium Mac in System Settings → Privacy & Security → Accessibility. If it is missing, use the button below, then toggle it on."
            statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            openSettingsButton.keyEquivalent = "\r"
            retryButton.isHidden = true
        } else if engine.tapStartFailed && !tapRunning {
            statusLabel.stringValue = "Keyboard tap failed to start"
            detailLabel.stringValue = engine.tapFailureMessage
                ?? "Accessibility is on, but the global key tap could not start. Enable Vimium Mac under Input Monitoring as well, then retry."
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            openSettingsButton.keyEquivalent = ""
            retryButton.isHidden = false
        } else if paused {
            statusLabel.stringValue = "Paused"
            detailLabel.stringValue = "Vimium Mac is running but not intercepting keys. Unpause here, from the menu bar, or with ⌃⌥⇧V."
            statusDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            openSettingsButton.keyEquivalent = ""
            retryButton.isHidden = tapRunning
        } else if tapRunning {
            statusLabel.stringValue = "Running"
            detailLabel.stringValue = "Accessibility granted. Hint mode and smooth scrolling work in Safari, Firefox, Discord, and other apps that are not excluded."
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            openSettingsButton.keyEquivalent = ""
            retryButton.isHidden = true
        } else {
            statusLabel.stringValue = "Waiting to start"
            detailLabel.stringValue = "Accessibility looks granted. Starting the keyboard tap…"
            statusDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            openSettingsButton.keyEquivalent = ""
            retryButton.isHidden = false
        }
    }

    @objc private func openAccessibilitySettings() {
        PermissionManager.promptIfNeeded()
        PermissionManager.openAccessibilitySettings()
    }

    @objc private func retryTap() {
        engine.retryKeyboardTap()
        refresh()
    }

    @objc private func togglePause() {
        engine.togglePaused()
        refresh()
    }

    @objc private func toggleLogin() {
        let next = !LaunchAtLogin.isEnabled
        if let error = LaunchAtLogin.setEnabled(next) {
            let alert = NSAlert()
            alert.messageText = "Could not update Login Items"
            alert.informativeText = error + "\n\nInstall Vimium Mac in /Applications and try again."
            alert.runModal()
        }
        refresh()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

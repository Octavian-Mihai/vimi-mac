import Foundation

/// Per-app enable list. Defaults disable terminals and editors so those apps
/// keep their own keybindings. Browsers and Discord stay on — the old Vimium
/// extension is gone, so this app owns Firefox, Chrome, Safari, etc.
final class AppExclusions {
    static let shared = AppExclusions()

    private let defaults = UserDefaults.standard
    private let extraDisabledKey = "extraDisabledBundleIDs"
    private let extraEnabledKey = "extraEnabledBundleIDs"
    private let pausedKey = "isPaused"
    private let browserMigrationKey = "migratedBrowserDefaultsV2"

    /// Bundle IDs that ship disabled. Safari, Firefox, Chrome, Discord are not listed.
    static let defaultDisabledBundleIDs: Set<String> = [
        // Terminals
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "org.alacritty",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "com.github.wez.wezterm",
        // Editors
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "dev.cursor.Cursor",
        "org.vim.MacVim",
        "com.macromates.TextMate",
    ]

    /// Previously default-disabled because the browser *extension* owned them.
    static let formerlyDefaultDisabledBrowsers: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.beta",
        "com.microsoft.edgemac.dev",
        "com.microsoft.edgemac.canary",
        "org.chromium.Chromium",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi",
    ]

    static let defaultDisabledPrefixes = [
        "com.jetbrains.",
    ]

    private init() {
        migrateFormerBrowserDefaults()
    }

    var isPaused: Bool {
        get { defaults.bool(forKey: pausedKey) }
        set {
            defaults.set(newValue, forKey: pausedKey)
            notify()
        }
    }

    private var extraDisabled: Set<String> {
        get { Set(defaults.stringArray(forKey: extraDisabledKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: extraDisabledKey) }
    }

    private var extraEnabled: Set<String> {
        get { Set(defaults.stringArray(forKey: extraEnabledKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: extraEnabledKey) }
    }

    func isEnabled(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return true }
        if extraEnabled.contains(bundleID) { return true }
        if extraDisabled.contains(bundleID) { return false }
        if Self.defaultDisabledBundleIDs.contains(bundleID) { return false }
        for prefix in Self.defaultDisabledPrefixes where bundleID.hasPrefix(prefix) {
            return false
        }
        return true
    }

    func isDefaultDisabled(bundleID: String) -> Bool {
        if Self.defaultDisabledBundleIDs.contains(bundleID) { return true }
        return Self.defaultDisabledPrefixes.contains { bundleID.hasPrefix($0) }
    }

    func setEnabled(_ enabled: Bool, bundleID: String) {
        var disabled = extraDisabled
        var enabledSet = extraEnabled
        if enabled {
            disabled.remove(bundleID)
            if isDefaultDisabled(bundleID: bundleID) {
                enabledSet.insert(bundleID)
            } else {
                enabledSet.remove(bundleID)
            }
        } else {
            enabledSet.remove(bundleID)
            if isDefaultDisabled(bundleID: bundleID) {
                disabled.remove(bundleID)
            } else {
                disabled.insert(bundleID)
            }
        }
        extraDisabled = disabled
        extraEnabled = enabledSet
        notify()
    }

    func toggle(bundleID: String) {
        setEnabled(!isEnabled(bundleID: bundleID), bundleID: bundleID)
    }

    func togglePaused() {
        isPaused.toggle()
    }

    /// Existing installs stored Firefox/Chrome in the disabled set only because
    /// they used to ship in the default-off list. Turn those back on once.
    private func migrateFormerBrowserDefaults() {
        guard !defaults.bool(forKey: browserMigrationKey) else { return }
        var disabled = extraDisabled
        var enabledSet = extraEnabled
        for id in Self.formerlyDefaultDisabledBrowsers {
            disabled.remove(id)
            enabledSet.remove(id)
        }
        extraDisabled = disabled
        extraEnabled = enabledSet
        defaults.set(true, forKey: browserMigrationKey)
    }

    private func notify() {
        NotificationCenter.default.post(name: .vimiumStateDidChange, object: self)
    }
}

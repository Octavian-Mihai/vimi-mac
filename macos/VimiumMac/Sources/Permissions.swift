import AppKit
import ApplicationServices
import ServiceManagement

enum PermissionManager {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for string in candidates {
            if let url = URL(string: string) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return nil }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered { return nil }
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

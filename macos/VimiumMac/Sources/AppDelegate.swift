import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: VimiumEngine?
    private var statusItem: StatusItemController?
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()

        let engine = VimiumEngine()
        self.engine = engine
        self.statusItem = StatusItemController(engine: engine)

        let windowController = MainWindowController(engine: engine)
        self.mainWindowController = windowController
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        engine.start()

        // Prompt after the window is on screen so Settings can list this process
        // as "Vimium Mac" rather than a hidden helper that never stays running.
        DispatchQueue.main.async {
            if !PermissionManager.isTrusted() {
                PermissionManager.promptIfNeeded()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func isMainWindowVisible() -> Bool {
        mainWindowController?.window?.isVisible == true
    }

    @objc func showMainWindow() {
        if mainWindowController == nil, let engine {
            mainWindowController = MainWindowController(engine: engine)
        }
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func hideMainWindow() {
        mainWindowController?.window?.orderOut(nil)
    }

    @objc func toggleMainWindow() {
        if isMainWindowVisible() {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    private func setupMainMenu() {
        let appName = "Vimium Mac"
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let showItem = windowMenu.addItem(
            withTitle: "Show Window",
            action: #selector(showMainWindow),
            keyEquivalent: "1"
        )
        showItem.target = self
        let hideItem = windowMenu.addItem(
            withTitle: "Hide Window",
            action: #selector(hideMainWindow),
            keyEquivalent: "w"
        )
        hideItem.target = self
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}

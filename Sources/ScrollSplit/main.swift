import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var infoItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var quitItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Avoid duplicate event taps that would reverse the same input twice.
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        model = AppModel()
        let view = SettingsView(model: model)
        let host = NSHostingController(rootView: view)
        window = NSWindow(contentViewController: host)
        window.title = "ScrollSplit"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
        window.isReleasedWhenClosed = false
        window.setContentSize(host.view.fittingSize)
        window.center()
        createMenu()
        model.statusChanged = { [weak self] in self?.updateMenu() }
        updateMenu()
        // SMAppService launches with a login-item Apple event; show onboarding if
        // permission has not been granted, otherwise keep login launches quiet.
        let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch || !model.trusted { showWindow() }
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: "ScrollSplit")
        let menu = NSMenu()
        infoItem = NSMenuItem(title: "ScrollSplit", action: nil, keyEquivalent: "")
        menu.addItem(infoItem)
        menu.addItem(.separator())
        settingsItem = NSMenuItem(title: "", action: #selector(showWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        pauseItem = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        quitItem = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func updateMenu() {
        guard statusItem != nil else { return }
        settingsItem.title = model.text("ScrollSplit Settings…", "ScrollSplit 설정…")
        quitItem.title = model.text("Quit ScrollSplit", "ScrollSplit 종료")
        pauseItem.title = model.enabled ? model.text("Pause", "일시 정지") : model.text("Resume ScrollSplit", "스크롤 분리 시작")
        infoItem.title = model.statusTitle
        statusItem.button?.toolTip = "ScrollSplit · \(model.statusTitle)"
        statusItem.button?.appearsDisabled = !model.running
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleEnabled() { model.enabled.toggle() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

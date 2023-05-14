import Cocoa
import SwiftUI
import ServiceManagement

var gIgnoreHideCount = 0

class CustomAppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    @Published var isMainWindowVisible: Bool = true // Add this line
    @Published var showWindow: Bool = false // Add this line
    @Published var startTimer: Bool = false // Add this line

    var mainWindow: NSWindow?
    var statusBarItem: NSStatusItem!
    var settingsWindow: NSWindow!

    func windowDidExitFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == mainWindow {
            DispatchQueue.main.async {
                self.mainWindow?.orderOut(nil)
                self.isMainWindowVisible = false
            }
        }
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        print("windowDidEnterFullScreen")
        startTimer.toggle()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = NSApplication.shared.windows.first
        if let window = mainWindow {
            window.setFrame(NSScreen.main?.frame ?? NSRect.zero, display: true, animate: true)
        }

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem.button {
            button.image = NSImage(named: "imageTop-16")
        }

        // Create the menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Show", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Start at login", action: #selector(openLoginItemsPreferences), keyEquivalent: "")
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")

        // Assign the menu to the status bar item
        statusBarItem.menu = menu

        // Initialize settings window
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.contentView = NSHostingView(rootView: SettingsView().environmentObject(self))
        settingsWindow.title = "Settings"
        settingsWindow.level = .floating
        settingsWindow.center()
        settingsWindow.isReleasedWhenClosed = false // Add this line

//        NSWindow.setFullScreen()
    }

    @objc func openLoginItemsPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showMainWindow() {
        showWindow.toggle() // To cause to call showApp.
        settingsWindow.orderOut(nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func openSettings(sender: AnyObject) {
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeFirstResponder(nil)
    }
}

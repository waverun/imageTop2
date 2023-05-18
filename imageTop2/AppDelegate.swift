import Cocoa
import SwiftUI
import ServiceManagement
import Quartz

//var gIgnoreHideCount = 0

@main
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    @AppStorage("startAfter") private var startAfter: TimeInterval = 600

    @Published var isMainWindowVisible: Bool = true // Add this line
    @Published var showWindow: Bool = true // Add this line
    @Published var startTimer: Bool = false // Add this line

    var statusBarItem: NSStatusItem!
    var settingsWindow: NSWindow!

    func windowWillClose(_ notification: Notification) {
        showMainWindow()
    }

    func windowDidExitFullScreen(_ notification: Notification) {

        if let window = notification.object as? NSWindow {
            window.orderOut(nil)
            debugPrint("window.orderOut")
            startInactivityTimer()
        }

        self.isMainWindowVisible = false
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        print("windowDidEnterFullScreen")
        inactivityTimer?.invalidate()
        startTimer.toggle()
    }

    var prevSeconds: CFTimeInterval = 0
    var inactivityTimer: Timer!

    func getLastEventTime() -> CFTimeInterval {
        let keyUpLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .keyUp)
        let mouseMoveLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .mouseMoved)
        let mouseDownLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .leftMouseDown)

        return min(keyUpLastTime, mouseMoveLastTime, mouseDownLastTime)
    }

    func startInactivityTimer() {
        if let inactivityTimer = inactivityTimer {
            inactivityTimer.invalidate()
        }

        prevSeconds = getLastEventTime()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            let currentSeconds = getLastEventTime()
            let secondsSinceLastEvent = currentSeconds - prevSeconds
            if secondsSinceLastEvent > startAfter { // check if the user hasz been inactive for more than 60 seconds
                self.showWindow = true // call your method that brings the window to the front
                WindowManager.shared.enterFullScreen()
            }
        }

    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApplication.shared.windows {
            if window.title == "Window" {
                window.orderOut(nil)
            }
        }
        
        createWindows()
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
        settingsWindow.delegate = self

//        NSWindow.setFullScreen()
    }


    func createWindows() {
        for (index, screen) in NSScreen.screens.enumerated() {
            let contentView = ContentView(index: index).environmentObject(self)

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.level = .normal
            window.collectionBehavior = [.fullScreenPrimary, .stationary, .canJoinAllSpaces, .ignoresCycle]
            window.delegate = self

            window.contentView = NSHostingView(rootView: contentView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeKeyAndOrderFront(nil)
            }
            WindowManager.shared.windows.append(window)
        }
        WindowManager.shared.enterFullScreen()
    }

    @objc func openLoginItemsPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference") {
            NSWorkspace.shared.open(url)
        }
    }

    func hideSettings() {
        if settingsWindow.isVisible {
            settingsWindow.orderOut(nil)
        }
    }

    @objc func showMainWindow() {
        WindowManager.shared.enterFullScreen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            hideSettings()
            showWindow = true // To cause to call showApp.
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func openSettings(sender: AnyObject) {
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeFirstResponder(nil)
    }

//    func applicationWillTerminate(_ notification: Notification) {
//        inactivityTimer.invalidate()
//    }
}

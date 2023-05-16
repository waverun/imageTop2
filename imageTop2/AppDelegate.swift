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

    func windowDidExitFullScreen(_ notification: Notification) {

        if let window = notification.object as? NSWindow {
            window.orderOut(nil)
            print("window.orderOut")
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
//            print("Seconds since last event: \(secondsSinceLastEvent)")
            if secondsSinceLastEvent > startAfter { // check if the user hasz been inactive for more than 60 seconds
                self.showWindow = true // call your method that brings the window to the front
                WindowManager.shared.enterFullScreen()
            }
        }

    }

    func applicationDidFinishLaunching(_ notification: Notification) {
//        mainWindow = NSApplication.shared.windows.first
//        if let window = mainWindow {
//            window.setFrame(NSScreen.main?.frame ?? NSRect.zero, display: true, animate: true)
//        }
//

        for window in NSApplication.shared.windows {
            if window.title == "Window" {
                window.orderOut(nil)
            }
        }
        
        createWindows()
//        showMainWindow()
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

    func createWindows() {
        var i = -1
        for screen in NSScreen.screens {
            i += 1
            let contentView = ContentView(index: i).environmentObject(self)
            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: [],
                                  backing: .buffered, defer: false, screen: screen)
            print("screen: \(screen.frame.size)")
            window.delegate = self // assign the delegate
            window.center()
            window.setFrame(screen.frame, display: true)
            window.contentView = NSHostingView(rootView: contentView)
            window.makeKeyAndOrderFront(nil)
            //            window.toggleFullScreen(nil) // Add this line

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

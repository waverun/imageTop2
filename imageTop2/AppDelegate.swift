import Cocoa
import SwiftUI
import ServiceManagement
import Quartz
//import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    @AppStorage("startAfter") private var startAfter: TimeInterval = 600

    @Published var isMainWindowVisible: Bool = true
    @Published var showWindow: Bool = true
    @Published var loadImages: Bool = false
    @Published var startTimer: Bool = false
    @Published var keyAndMouseEventMonitor: Any?

    var statusBarItem: NSStatusItem!
    var settingsWindow: NSWindow!
    var externalDisplayCount: Int = 0
    var screenChangeDetected: Bool = false
    var ignoreMonitor = false // To ignore key after Show menu

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

//    func wasWindowDidEnterFullScreen() {
//        print("windowDidEnterFullScreen")
//        inactivityTimer?.invalidate()
//        startTimer.toggle()
//    }

    var prevSeconds: CFTimeInterval = 0
    var inactivityTimer: Timer!
    var inactivityAfterLockTimer: Timer!

    func getLastEventTime() -> CFTimeInterval {
        let keyUpLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .keyUp)
        let mouseMoveLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .mouseMoved)
        let mouseDownLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .leftMouseDown)
        let scrollLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .scrollWheel)

        return min(keyUpLastTime, mouseMoveLastTime, mouseDownLastTime, scrollLastTime)
    }

    var prevEventTime: CFTimeInterval = 0

    func startInactivityTimer() {
        if let inactivityTimer = inactivityTimer {
            inactivityTimer.invalidate()
        }

        prevSeconds = getLastEventTime()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            let currentSeconds = getLastEventTime()
            if prevEventTime != currentSeconds {
                print("startInactivityTimer \(prevSeconds) \(currentSeconds)")
                prevEventTime = currentSeconds
            }
            let secondsSinceLastEvent = currentSeconds - prevSeconds
            if secondsSinceLastEvent > startAfter { // check if the user has been inactive for more than 60 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
                    self.showWindow = true // call your method that brings the window to the front
                }
                WindowManager.shared.enterFullScreen()
            }
        }
    }

    func startDetectLockedScreen() {
        let dnc = DistributedNotificationCenter.default()

        _ = dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            print("Screen Locked")
            ScreenLockStatus.shared.isLocked = true
        }

        _ = dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            print("Screen Unlocked")
            ScreenLockStatus.shared.isLocked = false
        }
    }

//    // Method called when screen locks
//    @objc func screenDidLock() {
//        print("Screen is locked")
//        ScreenLockStatus.shared.isLocked = true
//    }
//
//    // Method called when screen unlocks
//    @objc func screenDidUnlock() {
//        print("Screen is unlocked")
//        ScreenLockStatus.shared.isLocked = false
//    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApplication.shared.windows {
            if window.title == "Window" {
                window.orderOut(nil)
            }
        }

        startDetectLockedScreen()
//        WindowManager.shared.appDelegate = self
        
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

        // setup the screen change notification
        externalDisplayCount = NSScreen.screens.count

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayConnection),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        showWindow = true
    }

    @objc func handleDisplayConnection(notification: Notification) {
        if externalDisplayCount != NSScreen.screens.count {
            externalDisplayCount = NSScreen.screens.count

            print("A screen was added or removed.")
            // Remove all current windows
            
            restartApplication()

            screenChangeDetected = true // used to create windows again on user input to prevent problem when the screen was locked
        } else {
            print("A display configuration change occurred.")
            // Handle any other display configuration changes if needed
        }
    }

//    func startWaitingForUserInputAfterLockTimer() {
//        inactivityAfterLockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
//            let currentSeconds = getLastEventTime()
//            let secondsSinceLastEvent = currentSeconds - prevSeconds
//            if secondsSinceLastEvent > startAfter { // check if the user has been inactive for more than 60 seconds
//                if screenChangeDetected {
//                    // Wait until user input is detected
//                    if getLastEventTime() < prevSeconds {
//                        // User input detected, restart the application
//                        restartApplication()
//                        screenChangeDetected = false
//                        inactivityAfterLockTimer.invalidate()
//                    }
//                }
////                else {
////                    self.showWindow = true // call your method that brings the window to the front
////                    WindowManager.shared.enterFullScreen()
////                }
//            }
//        }
//    }


    // This is just a placeholder function, replace it with your actual restart logic
    var createWindowsPlease = true

    func restartApplication() {
        print("Restarting application...")
        
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in // to prevent 1 bip when opening the lid with lock. Probably the lock status is set after opening the screen.
        //        if WindowManager.shared.isFullScreen() {
        //
        //        }
        
        WindowManager.shared.removeAllWindows() { [self] in
            // Recreate windows for the new screen configuration
            print("before createWindows")
            //??:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                if createWindowsPlease {
                    print("NSScreen.screens.count before createWindow: \(NSScreen.screens.count) ")
                    createWindows()
//                    createWindowsPlease.toggle()
                }
                print("after createWindows")
            }
        }
        //        }
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
            WindowManager.shared.addWindow(window)
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
            print("showMainWindow")
            ignoreMonitor = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                ignoreMonitor = false
            }
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
}

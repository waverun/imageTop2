import Cocoa
import SwiftUI
import ServiceManagement
import Quartz

@main
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    @AppStorage("startAfter")  var startAfter: TimeInterval = 600

    @Published var isMainWindowVisible: Bool = true
    @Published var showWindow: Bool = true
    @Published var loadImagesAndVideos: Bool = false
    @Published var startTimer: Bool = false
    @Published var keyAndMouseEventMonitor: Any?
    @Published var pexelsPhotos: [String] = []
    @Published var pexelsVideos: [String] = []
    @Published var networkIsReachable = false
    @Published var isFullScreen = false

    @Published var autoStart: Bool = true {
        didSet {
            // Update the title of the menu item when autoStart changes
            autoStartItem.title = (autoStart ? "Disable" : "Enable") + " Auto (Inactivity) Start"
        }
    }

    @AppStorage("showWatch") var showWatch = true {
        didSet {
            // Update the title of the menu item when autoStart changes
            showWatchItem.title = (showWatch ? "Hide" : "Show") + " Watch"
        }
    }

    var statusBarItem: NSStatusItem!
    var autoStartItem: NSMenuItem! // This is the menu item we want to update
    var showWatchItem: NSMenuItem! // This is the menu item we want to update

    var settingsWindow: NSWindow!
    var externalDisplayCount: Int = 0
    var screenChangeDetected: Bool = false
    var ignoreMonitor = false // To ignore key after Show menu
    var firstSetTimer: [Int : Bool] = [:]
    var networkManager = NetworkManager(appDelegate: nil)
    var dnc: DistributedNotificationCenter!
    var screenLockedObserver: NSObjectProtocol?
    var screenUnlockedObserver: NSObjectProtocol?

    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        stopDetectLockedScreen()
        dnc.removeObserver(self)
    }

    func stopDetectLockedScreen() {
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }

        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        showMainWindow()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        NSCursor.unhide()
        isFullScreen = false
        if let window = notification.object as? NSWindow {
            window.orderOut(nil)
            iPrint("window.orderOut \(String(describing: index))")
            if !ScreenLockStatus.shared.isLocked {
                startInactivityTimer()
            }
            if let index = WindowManager.shared.getIndex(for: window),
               gTimers.count > index,
               gPlayers.count > index,
               let player = gPlayers[index] {
                player.pause()
                if let timer = gTimers[index] {
                    timer.pause()
                }
                iPrint("video1 pause \(index)")
                if index == WindowManager.shared.windows.count - 1 {
//                    for window in NSApp.windows {
                    for window in WindowManager.shared.windows {
                        window.orderOut(nil)
                    }
                }
            }
        }

        isMainWindowVisible = false
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
        iPrint("windowDidEnterFullScreen")
        inactivityTimer?.invalidate()
        startTimer.toggle()
        showWindow = true
        NSCursor.hide()
    }

    var inactivityTimer: Timer!

    func getLastEventTime() -> CFTimeInterval {
        let keyUpLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .keyUp)
        let mouseMoveLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .mouseMoved)
        let mouseDownLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .leftMouseDown)
        let scrollLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .scrollWheel)

        return min(keyUpLastTime, mouseMoveLastTime, mouseDownLastTime, scrollLastTime)
    }

    func startInactivityTimer() {
        if let inactivityTimer = inactivityTimer {
            inactivityTimer.invalidate()
        }

        if !autoStart {
            return
        }

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            let currentSeconds = self.getLastEventTime()
               if currentSeconds > startAfter { // check if the user has been inactive for more than 60 seconds
                if autoStart {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        guard let self = self else { return }
                        self.showWindow = true // call your method that brings the window to the front
                    }
                    WindowManager.shared.enterFullScreen()
                }
                inactivityTimer.invalidate()
                inactivityTimer = nil
            }
        }
    }

    func startDetectLockedScreen() {
        dnc = DistributedNotificationCenter.default()

        screenLockedObserver = dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            iPrint("Screen Locked")
            ScreenLockStatus.shared.isLocked = true
            showWindow = false
            inactivityTimer?.invalidate()
            inactivityTimer = nil
        }

        screenUnlockedObserver = dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            iPrint("Screen Unlocked")
            ScreenLockStatus.shared.isLocked = false
            startInactivityTimer()
        }
    }


    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        iPrint("Memory: Start applicationDidFinishLaunching: \(reportMemory())")
#endif

        for window in NSApplication.shared.windows {
            if window.title == "Window" {
                window.orderOut(nil)
            }
        }

        startDetectLockedScreen()

        createWindows()

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem.button {
            button.image = NSImage(named: "imageTop-16")
        }

        // Create the menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Show", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: "")
        autoStartItem = menu.addItem(withTitle: (autoStart ? "Disable" : "Enable") + " Auto (Inactivity) Start", action: #selector(handleAutoStart), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        showWatchItem = menu.addItem(withTitle: (showWatch ? "Hide" : "Show") + " Watch", action: #selector(showWatchToggle), keyEquivalent: "")
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

        networkManager = NetworkManager(appDelegate: self)

#if DEBUG
        iPrint("Finished: Start applicationDidFinishLaunching: \(reportMemory())")
#endif
    }

    @objc func showWatchToggle() {
        showWatch.toggle()
    }

    @objc func handleAutoStart() {
        autoStart.toggle()
        switch true {
            case autoStart: startInactivityTimer()
            default:
                inactivityTimer?.invalidate()
                inactivityTimer = nil
        }
    }

    @objc func handleDisplayConnection(notification: Notification) {
        if externalDisplayCount != NSScreen.screens.count {
            externalDisplayCount = NSScreen.screens.count

            iPrint("A screen was added or removed.")
            // Remove all current windows
            
            restartApplication()
//            restart()

            screenChangeDetected = true // used to create windows again on user input to prevent problem when the screen was locked
        } else {
            iPrint("A display configuration change occurred.")
            // Handle any other display configuration changes if needed
        }
    }

    // This is just a placeholder function, replace it with your actual restart logic
//    var createWindowsPlease = true

    func restartApp() {
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        let task = Process()
        task.executableURL = Bundle.main.executableURL // gets the current executable
        do {
            try task.run()
        } catch {
            print("Failed to run the task: \(error)")
        }
        NSApp.terminate(self)

//        exit(0) // terminates the current app
                //        }
    }

    func restart() {
        let appleScript = "do shell script \"open -b \(Bundle.main.bundleIdentifier!)\""
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(nil)
        }
        exit(0)
    }

//    func restart() {
//        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-b", Bundle.main.bundleIdentifier!])
////        NSApp.terminate(self)
//        exit(0)
//    }

    func restartApplication() {
        iPrint("Restarting application...")
        WindowManager.shared.removeAllWindows() { [weak self] in
            guard let self = self else { return }
            iPrint("before createWindows")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                    iPrint("NSScreen.screens.count before createWindow: \(NSScreen.screens.count) ")
                    self.createWindows()
                iPrint("after createWindows")
            }
        }
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
        if autoStart {
            WindowManager.shared.enterFullScreen()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.hideSettings()
            iPrint("showMainWindow")
            self.ignoreMonitor = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self = self else { return }
                self.ignoreMonitor = false
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

import Cocoa
import SwiftUI
import ServiceManagement
import Quartz

@main
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    @AppStorage("startAfter")  var startAfter: TimeInterval = 600

    @Published var videoPlayerViewOpacity = 1.0
    @Published var isMainWindowVisible: Bool = true
    @Published var showWindow: Bool = true
    @Published var loadImagesAndVideos: Bool = false
    @Published var startMonitoringUserInputTimer: Bool = false
    @Published var keyAndMouseEventMonitor: Any?
    @Published var pexelsPhotos: [String] = []
    @Published var pexelsVideos: [String] = []
    @Published var networkIsReachable = false
    @Published var isFullScreen = false
    @Published var setImageOrVideoModeToggle = false
    @Published var downloading = false
    @Published var numberOfLocalImagesAndVideos = 0
    @Published var numberOfPexelsPhotos = 0
    @Published var numberOfPexelsVideos = 0

    @Published var autoStart: Bool = true {
        didSet {
            // Update the title of the menu item when autoStart changes
            autoStartItem.title = (autoStart ? "Disable" : "Enable") + " Auto (Inactivity) Start"
        }
    }

    @AppStorage("hotKeyString") var keyString: String = "escape"
    @AppStorage("modifierKeyString1") var keyString1: String = "command"
    @AppStorage("modifierKeyString2") var keyString2: String = "control"

    @AppStorage("showWatch") var showWatch = true {
        didSet {
            // Update the title of the menu item when autoStart changes
            showWatchItem.title = (showWatch ? "Hide" : "Show") + " Watch"
        }
    }

    var statusBarItem: NSStatusItem!
    var autoStartItem: NSMenuItem! // This is the menu item we want to update
    var showWatchItem: NSMenuItem! // This is the menu item we want to update
    var showItem: NSMenuItem! // This is the menu item we want to update

    var settingsWindow: NSWindow!
    var externalDisplayCount: Int = 0
    var ignoreMonitor = false // To ignore key after Show menu
    var firstSetTimer: [Int : Bool] = [:]
    var networkManager = NetworkManager(appDelegate: nil)
    var dnc: DistributedNotificationCenter!
    var screenLockedObserver: NSObjectProtocol?
    var screenUnlockedObserver: NSObjectProtocol?
    var restartApplicationWhileScreenIsLockedOccured = false

    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        stopDetectLockedScreen()
        dnc.removeObserver(self)
    }

    func setDownloading(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.downloading = value
        }
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
               gPlayers.count > index,
               let player = gPlayers[index] {
                player.pause()
                if gPausableTimers.count > index {
                    if let timer = gPausableTimers[index] {
                        timer.pause()
                    }
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
        iPrint("windowDidEnterFullScreen didntEnterFullScreenYet: \(WindowManager.shared.didntEnterFullScreenYet)")
        inactivityTimer?.invalidate()
        NSCursor.hide()
        WindowManager.shared.didntEnterFullScreenYet -= 1
        if WindowManager.shared.didntEnterFullScreenYet == 0 {
            startMonitoringUserInputTimer.toggle()
            showWindow = true
        }
    }

    var inactivityTimer: Timer!

    func getLastEventTime() -> CFTimeInterval {
        let keyUpLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .keyUp)
        let mouseMoveLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .mouseMoved)
        let mouseDownLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .leftMouseDown)
        let scrollLastTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .scrollWheel)

        return min(keyUpLastTime, mouseMoveLastTime, mouseDownLastTime, scrollLastTime)
    }

    func startInactivityTimer(passTime: Double = 0) {
        if let inactivityTimer = inactivityTimer {
            inactivityTimer.invalidate()
        }

        if !autoStart {
            return
        }

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: startAfter - passTime, repeats: false) { [weak self] timer in
            guard let self = self else { return }
            let currentSeconds = self.getLastEventTime()
            let remainingTime = max(self.startAfter, 5) - currentSeconds
            switch true {
                case remainingTime <= 0:
                        if autoStart {
                            WindowManager.shared.enterFullScreen()
                        }
                        inactivityTimer.invalidate()
                        inactivityTimer = nil
                default : startInactivityTimer(passTime: remainingTime)
            }
        }
    }

    func applicationDidResignActive(_ aNotification: Notification) {
        // This method is called when the application loses focus
        print("Application is not active")
        if WindowManager.shared.windows[0].styleMask.contains(.fullScreen) {
            showWindow = false
        }
    }

    func applicationShouldHandleReopen(_ theApplication: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            iPrint("applicationShouldHandleReopen")
            if !showWindow {
                showMainWindow()
            }
            // Handle the scenario where there are no visible windows when the Dock icon is clicked
            // For instance, you can makeKeyAndOrderFront your main window here
        }
        return true
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
            if restartApplicationWhileScreenIsLockedOccured {
                restartApplicationWhileScreenIsLockedOccured = false
                restartApplication()
                iPrint("screenUnlockedObserver: \(restartApplicationWhileScreenIsLockedOccured)")
            }
        }
    }


    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        iPrint("Memory: Start applicationDidFinishLaunching: \(reportMemory())")
#endif

        WindowManager.shared.appDelegate = self
        
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

        showItem = menu.addItem(withTitle: "Show", action: #selector(showMainWindow), keyEquivalent: "")

        updateShowItem()

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

//    func addShowItem(menu: NSMenu) {

//        let mod1 = Keyboard.stringToModifier(keyString1)
//        let mod2 = Keyboard.stringToModifier(keyString2)
//
//        switch true {
//            case (mod1 != nil && mod2 != nil):
//                showItem = menu.addItem(withTitle: "Show", action: #selector(showMainWindow), keyEquivalent: keyString)
//                showItem.keyEquivalentModifierMask = [mod1!, mod2!]
//            default:
//                showItem = menu.addItem(withTitle: "Show", action: #selector(showMainWindow), keyEquivalent: "")
//                // Optionally handle the case where one or both modifiers were not valid
//                print("Invalid modifier strings provided.")
//        }
//    }

//    func updateShowItem() {
//        let mod1 = Keyboard.stringToModifier(keyString1)
//        let mod2 = Keyboard.stringToModifier(keyString2)
//
//        switch true {
//            case (mod1 != nil && mod2 != nil):
//                showItem.keyEquivalent = keyString
//                showItem.keyEquivalentModifierMask = [mod1!, mod2!]
//            default:
//                showItem.keyEquivalent = ""
//                showItem.keyEquivalentModifierMask = []
//                // Optionally handle the case where one or both modifiers were not valid
//                print("Invalid modifier strings provided.")
//        }
//    }

    func updateShowItem() {
//        let keyString = Keyboard.keySymbol(from: keyString, forMenu: true)
        let keyString = Keyboard.keyEquivalentString(from: keyString, forMenu: true)
        let mod1 = keyString1 != "None" ? Keyboard.stringToModifier(keyString1) : nil
        let mod2 = keyString2 != "None" ? Keyboard.stringToModifier(keyString2) : nil

        showItem.keyEquivalent = keyString

        switch (mod1, mod2) {
            case let (mod1?, mod2?):
//                showItem.keyEquivalent = keyString
                showItem.keyEquivalentModifierMask = [mod1, mod2]
            case let (mod1?, nil):
//                showItem.keyEquivalent = keyString
                showItem.keyEquivalentModifierMask = [mod1]
            case let (nil, mod2?):
//                showItem.keyEquivalent = keyString
                showItem.keyEquivalentModifierMask = [mod2]
            case (nil, nil):
//                showItem.keyEquivalent = keyString
                showItem.keyEquivalentModifierMask = []
        }
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

            restartApplication()
        } else {
            iPrint("A display configuration change occurred.")
            // Handle any other display configuration changes if needed
        }
    }

    func restartApplication() {
        if ScreenLockStatus.shared.isLocked {
            restartApplicationWhileScreenIsLockedOccured = true
            iPrint("restartApplication: restartApplicationWhileScreenIsLockedOccured: \(restartApplicationWhileScreenIsLockedOccured)")
            return
        }
        iPrint("Restarting application...")
        WindowManager.shared.removeAllWindows() { [weak self] in
            guard let self = self else { return }
            iPrint("before createWindows")
            showWindow = false
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
        if settingsWindow == nil {
            return
        }

        if settingsWindow.isVisible {
            settingsWindow.orderOut(nil)
        }
    }

    @objc func showMainWindow() {
        if !autoStart {
            handleAutoStart()
        }
        WindowManager.shared.enterFullScreen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
//            self.hideSettings()
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

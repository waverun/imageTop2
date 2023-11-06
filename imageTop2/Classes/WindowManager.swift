import SwiftUI

class WindowManager: ObservableObject {
//    weak var appDelegate: AppDelegate!
    var enterFullScreenTimer: Timer? = nil
    var exitFullScreenTimer: Timer? = nil
    var appDelegate: AppDelegate!

    static let shared = WindowManager()
    var windows: [NSWindow] = []
    var windowIndices = ThreadSafeDict<NSWindow, Int>()
//    var windowIndices: [NSWindow: Int] = [:] // new dictionary to hold window indices
    var didntEnterFullScreenYet = 0

    func getMaxScreenWidth() -> Int {
        if let maxWindowWidth = windows.max(by: { $0.frame.size.width < $1.frame.size.width })?.frame.size.width {
            iPrint("Max window width: \(maxWindowWidth)")
            return Int(maxWindowWidth)
        } else {
            iPrint("Array of windows is empty.")
            return 0
        }
    }
    
    func getIndex(for window: NSWindow) -> Int? {
        return windowIndices[window]
    }

    func addWindow(_ window: NSWindow) {
        windows.append(window)
        windowIndices[window] = windows.count - 1 // assign an index to each window
    }

    func removeAllWindows(completion: @escaping () -> Void) {
        func removeTimers() {
            for i in 0...gPausableTimers.count {
                if i < gPausableTimers.count {
                    if gPausableTimers[i] != nil {
                        gPausableTimers[i]!.invalidate()
                        gPausableTimers[i] = nil
                    }
                }
            }
            gPausableTimers.removeAll()
        }

        func removePlayers() {
            for i in 0...gPlayers.count {
                if i < gPlayers.count {
                    if gPlayers[i] != nil {
                        gPlayers[i]!.pause()
                        gPlayers[i] = nil
                    }
                }
            }
            gPlayers.removeAll()
        }

        func cleanStateObjects() {
            for key in Array(gStateObjects.keys) {
                gStateObjects[key]?.firstVideoPath = nil
                gStateObjects[key]?.secondVideoPath = nil
                gStateObjects[key]?.unusedPaths.removeAll()
            }
            gStateObjects.removeAll()
//            gStateObjects = [:]
        }

        func cleanContentViews() {
            gContentViews.removeAll()
//            gContentViews = [:]
        }

        func cleanVideoObserversAndTasks() {
            for videoLengthTask in gVideoLengthTasks.values {
                videoLengthTask.cancel()
            }
            for endPlayNotification in gEndPlayNotifications.values {
                NotificationCenter.default.removeObserver(endPlayNotification)
            }
        }

        exitFullScreen() { [weak self] in
            guard let self = self else { return }
            gHotkey?.keyDownHandler = nil
            gHotkey = nil
            gDirectoryWatcher?.release()
            gDirectoryWatcher = nil
            removePlayers()
            removeTimers()
            cleanStateObjects()
            cleanContentViews()
            cleanVideoObserversAndTasks()
            windowIndices.removeAll()

            var index = 0
            for window in windows {
                window.orderOut(NSApp)
                window.contentView = nil
                //                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                iPrint("Before window.close \(index)")
                window.isReleasedWhenClosed = true
                window.displaysWhenScreenProfileChanges = false
                window.disableScreenUpdatesUntilFlush()
                window.delegate = nil
                windows.removeAll(where: { $0 == window })
                window.performClose(nil)
                index += 1
            }
            windows.removeAll()
            completion()
            iPrint("end exitFullScreen")
        }
    }

    func toggleFullScreen(_ exitFullStcreen: Bool) {
        for (index, window) in windows.enumerated() {
            if window.styleMask.contains(.fullScreen) {
                if exitFullStcreen {
                    iPrint("exitFullScreend - toggle \(index)")
                    //                    window.orderOut(nil) //??
                    window.toggleFullScreen(nil)
                }
            } else {
                if !exitFullStcreen {
                    iPrint("enterFullScreend - toggle \(index)")
                    window.toggleFullScreen(nil)
                }
            }
        }
    }

    func enterFullScreen() {
        if windows.count == 0 {
            return
        }

        appDelegate.toggleVideoBlur(toValue: false) {}

        appDelegate.hideSettings()
        
        NSMenu.setMenuBarVisible(false)

        didntEnterFullScreenYet = windows.count
        
        if !windows[0].styleMask.contains(.fullScreen) {
            toggleFullScreen(false)
        }

        if !ScreenLockStatus.shared.isLocked {
            return
        }

        iPrint("enterFullScreen - not locked")
//         Invalidate the timer if it exists
        exitFullScreenTimer?.invalidate()

        // Create a new timer
        enterFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if !ScreenLockStatus.shared.isLocked {
                var invalidateTimerRequired = true
//                if let windows = self.windows {
                    for window in windows {
                        if !window.styleMask.contains(.fullScreen) {
                            window.toggleFullScreen(nil)
                            invalidateTimerRequired = false
                        }
                    }
//                }
                if invalidateTimerRequired {
                    timer.invalidate()
                }
            }
        }
    }

    func stopPlayingVideos() {
        for player in gPlayers {
            player.value.pause()
            gPausableTimers[player.key]?.pause()
        }
    }

    func exitFullScreen(completion: (() -> Void)? = nil) {
        NSApp.deactivate()
        NSApp.keyWindow?.resignFirstResponder()

//        stopPlayingVideos()

        appDelegate.toggleVideoBlur(toValue: true) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self.toggleFullScreen(true)

            if !ScreenLockStatus.shared.isLocked {
                if let completion = completion {
                    completion()
                    return
                }
                return
            }
            // Invalidate the timer if it exists
            self.enterFullScreenTimer?.invalidate()

            // Create a new timer
            self.exitFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                if !ScreenLockStatus.shared.isLocked {
                    var invalidateTimerRequired = true
                    //                if let windows = self.windows {
                    for window in windows {
                        if window.styleMask.contains(.fullScreen) {
                            window.toggleFullScreen(nil)
                            invalidateTimerRequired = false
                        }
                    }
                    //                }
                    if invalidateTimerRequired {
                        timer.invalidate()
                        if let completion = completion {
                            completion()
                            return
                        }
                    }
                }
            }
        }
    }

    func isFullScreen() -> Bool {
        for window in windows {
            if window.styleMask.contains(.fullScreen) {
                return true
            }
        }
        return false
    }
}

import SwiftUI

class WindowManager: ObservableObject {
//    weak var appDelegate: AppDelegate!
    var enterFullScreenTimer: Timer? = nil
    var exitFullScreenTimer: Timer? = nil

    static let shared = WindowManager()
    var windows: [NSWindow] = []
    var windowIndices: [NSWindow: Int] = [:] // new dictionary to hold window indices

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
            gStateObjects = [:]
        }
//        func cleanContentViews() {
//            for contentView in Array(gContentViews.values) {
//                contentView.stateObjects.firstVideoPath = ""
//                contentView.stateObjects.secondVideoPath = ""
//                contentView.stateObjects.unusedPaths.removeAll()
//            }
//            gContentViews = [:]
//        }
        exitFullScreen() { [weak self] in
            guard let self = self else { return }
            removePlayers()
            removeTimers()
            cleanStateObjects()
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
//                window.close()
                //                }
                index += 1
            }
            windows.removeAll()
            completion()
            iPrint("end exitFullScreen")
        }
    }

    func toggleFullScreen(_ exitFullStcreen: Bool) {
        for window in windows {
            if window.styleMask.contains(.fullScreen) {
                if exitFullStcreen {
                    iPrint("exitFullScreend - toggle")
                    window.orderOut(nil) //??
                    window.toggleFullScreen(nil)
                }
            } else {
                if !exitFullStcreen {
                    iPrint("enterFullScreend - toggle")
                    window.toggleFullScreen(nil)
                }
            }
        }
    }

    func enterFullScreen() {
        if windows.count == 0 {
            return
        }

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

    func exitFullScreen(completion: (() -> Void)? = nil) {
        toggleFullScreen(true)

        if !ScreenLockStatus.shared.isLocked {
            if let completion = completion {
                completion()
                return
            }
            return
        }
        // Invalidate the timer if it exists
        enterFullScreenTimer?.invalidate()

        // Create a new timer
        exitFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
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

    func isFullScreen() -> Bool {
        for window in windows {
            if window.styleMask.contains(.fullScreen) {
                return true
            }
        }
        return false
    }
}

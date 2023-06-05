import SwiftUI

class WindowManager: ObservableObject {
//    weak var appDelegate: AppDelegate!
    var enterFullScreenTimer: Timer? = nil
    var exitFullScreenTimer: Timer? = nil

    static let shared = WindowManager()
    private var windows: [NSWindow] = []

    func addWindow(_ window: NSWindow) {
        windows.append(window)
    }

    func removeAllWindows(completion: @escaping () -> Void) {
        exitFullScreen() { [self] in
            windows.removeAll()
            completion()
        }
    }

    func toggleFullScreen(_ exitFullStcreen: Bool) {
        for window in windows {
            if window.styleMask.contains(.fullScreen) {
                if exitFullStcreen {
                    window.toggleFullScreen(nil)
                }
            } else {
                if !exitFullStcreen {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }

    func enterFullScreen() {
        if !windows[0].styleMask.contains(.fullScreen) {
            toggleFullScreen(false)
        }

        if !ScreenLockStatus.shared.isLocked {
            return
        }

        print("enterFullScreen - not locked")
//         Invalidate the timer if it exists
        exitFullScreenTimer?.invalidate()

        // Create a new timer
        enterFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if !ScreenLockStatus.shared.isLocked {
                var invalidetTimerRequired = true
                for window in windows {
                    if !window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                        invalidetTimerRequired = false
                    }
                }
                if invalidetTimerRequired {
                    timer.invalidate()
                }
            }
        }
    }

    func exitFullScreen(completion: (() -> Void)? = nil) {
        if windows[0].styleMask.contains(.fullScreen) {
            toggleFullScreen(true)
        }

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
        exitFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if !ScreenLockStatus.shared.isLocked {
                var invalidetTimerRequired = true
                for window in windows {
                    if window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                        invalidetTimerRequired = false
                    }
                }
                if invalidetTimerRequired {
                    timer.invalidate()
                    if let completion = completion {
                        completion()
                        return
                    }
                }
            }
        }
    }

//    func enterFullScreen() {
//        if !windows[0].styleMask.contains(.fullScreen) {
//            toggleFullScreen(false)
//        }
//    }
//
//    func exitFullScreen() {
//        if windows[0].styleMask.contains(.fullScreen) {
//            toggleFullScreen(true)
//        }
//    }

    func isFullScreen() -> Bool {
        for window in windows {
            if window.styleMask.contains(.fullScreen) {
                return true
            }
        }
        return false
    }
}

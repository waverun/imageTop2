import SwiftUI

class WindowManager: ObservableObject {
//    weak var appDelegate: AppDelegate!
    var enterFullScreenTimer: Timer? = nil
    var exitFullScreenTimer: Timer? = nil

    static let shared = WindowManager()
    var windows: [NSWindow] = []
//    var fullScreen = false

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

        // Invalidate the timer if it exists
        exitFullScreenTimer?.invalidate()

        // Create a new timer
        enterFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            var invalideTimerRequired = true
            for window in windows {
                if !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                    invalideTimerRequired = false
                }
            }
            if invalideTimerRequired {
                timer.invalidate()
            }
        }
    }

    func exitFullScreen() {
        if windows[0].styleMask.contains(.fullScreen) {
            toggleFullScreen(true)
        }

        // Invalidate the timer if it exists
        enterFullScreenTimer?.invalidate()

        // Create a new timer
        exitFullScreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            var invalideTimerRequired = true
            for window in windows {
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
            if invalideTimerRequired {
                timer.invalidate()
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

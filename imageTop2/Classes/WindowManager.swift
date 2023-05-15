import SwiftUI

class WindowManager: ObservableObject {
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
    }

    func exitFullScreen() {
        if windows[0].styleMask.contains(.fullScreen) {
            toggleFullScreen(true)
        }
    }
}

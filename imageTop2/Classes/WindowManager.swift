import SwiftUI

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    var windows: [NSWindow] = []
    var fullScreen = false

    func toggleFullScreen() {
        for window in windows {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            } else {
                window.toggleFullScreen(nil)
            }
        }
    }

    func enterFullScreen() {
        if !fullScreen {
            fullScreen = true
            toggleFullScreen()
        }
    }

    func exitFullScreen() {
        if fullScreen {
            fullScreen = false
            toggleFullScreen()
        }
    }
}

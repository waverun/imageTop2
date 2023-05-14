import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

//    var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        var i = -1
        for screen in NSScreen.screens {
            i += 1
            let contentView = ContentView()
            let window = NSWindow(contentRect: screen.frame,
                               styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                               backing: .buffered, defer: false, screen: screen)
            window.center()
            window.setFrame(screen.frame, display: true)
            window.contentView = NSHostingView(rootView: contentView)
            window.makeKeyAndOrderFront(nil)
//            window.toggleFullScreen(nil) // Add this line

            WindowManager.shared.windows.append(window)
        }
        WindowManager.shared.enterFullScreen()
    }
}

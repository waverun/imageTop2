import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windows: [NSWindow] = []
//    var window2: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Grab the screens
//        let screens = NSScreen.screens
//        guard screens.count >= 2 else {
//            print("Less than two screens connected.")
//            return
//        }

        // Create a SwiftUI view for each window
//        let contentView1 = ContentView().background(Color.red)
//        let contentView2 = ContentView().background(Color.blue)

        // Create the first window
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
            window.toggleFullScreen(nil) // Add this line

            windows.append(window)
            // Create the second window
//            window2 = NSWindow(contentRect: screens[1].frame,
//                               styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
//                               backing: .buffered, defer: false, screen: screens[1])
//            window2.center()
//            window2.setFrame(screens[1].frame, display: true)
//            window2.contentView = NSHostingView(rootView: contentView2)
//            window2.makeKeyAndOrderFront(nil)
//            window2.toggleFullScreen(nil) // Add this line
        }
    }
}

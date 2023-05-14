import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window1: NSWindow!
    var window2: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Grab the screens
        let screens = NSScreen.screens
        guard screens.count >= 2 else {
            print("Less than two screens connected.")
            return
        }

        // Create a SwiftUI view for each window
        let contentView1 = ContentView().background(Color.red)
        let contentView2 = ContentView().background(Color.blue)

        // Create the first window
        window1 = NSWindow(contentRect: screens[0].frame,
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false, screen: screens[0])
        window1.center()
        window1.setFrame(screens[0].frame, display: true)
        window1.contentView = NSHostingView(rootView: contentView1)
        window1.makeKeyAndOrderFront(nil)
        window1.toggleFullScreen(nil) // Add this line

        // Create the second window
        window2 = NSWindow(contentRect: screens[1].frame,
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false, screen: screens[1])
        window2.center()
        window2.setFrame(screens[1].frame, display: true)
        window2.contentView = NSHostingView(rootView: contentView2)
        window2.makeKeyAndOrderFront(nil)
        window2.toggleFullScreen(nil) // Add this line
    }
}

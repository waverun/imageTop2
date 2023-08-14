import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainAppIdentifier = "com.imageTop.ImageTop"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == mainAppIdentifier
        }

        if !isRunning {
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("imageTop") //main app name

            let newPath = NSString.path(withComponents: components)

            let configuration = NSWorkspace.OpenConfiguration()
            let appUrl = URL(fileURLWithPath: "/Applications/imageTop.app")

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                NSWorkspace.shared.openApplication(at: appUrl, configuration: configuration) { app, error in
                    if let error = error {
                        print("An error occurred: \(error)")
                    } else if let app = app {
                        print("Opened app: \(app)")
                    }
                }
                NSApp.terminate(nil)
            }
            //            NSWorkspace.shared.launchApplication(newPath)
        } else {
            NSApp.terminate(nil)
        }
    }
}

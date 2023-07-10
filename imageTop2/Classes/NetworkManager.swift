import Reachability
import SwiftUI

var gNetworkIsReachable = false

class NetworkManager {
//    @EnvironmentObject var appDelegate: AppDelegate

    let reachability = try! Reachability()

    var isConnected: Bool {
        return reachability.connection != .unavailable
    }

    init(appDelegate: AppDelegate?) {
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                iPrint("Reachable via WiFi")
                gNetworkIsReachable = true
                appDelegate?.networkIsReachable = true
            } else {
                iPrint("Reachable via Cellular")
                gNetworkIsReachable = false
                appDelegate?.networkIsReachable = false
            }
        }
        reachability.whenUnreachable = { _ in
            iPrint("Not reachable")
            gNetworkIsReachable = false
            appDelegate?.networkIsReachable = false
        }

        do {
            try reachability.startNotifier()
        } catch {
            iPrint("Unable to start notifier")
        }
    }

    deinit {
        reachability.stopNotifier()
    }
}

import Reachability

class NetworkManager {

    let reachability = try! Reachability()

    var isConnected: Bool {
        return reachability.connection != .unavailable
    }

    init() {
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        }
        reachability.whenUnreachable = { _ in
            print("Not reachable")
        }

        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
    }

    deinit {
        reachability.stopNotifier()
    }
}

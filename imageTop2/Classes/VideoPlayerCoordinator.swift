import AVFoundation

class VideoPlayerCoordinator: NSObject {
    var parent: VideoPlayerView
    let finishedPlaying: () -> Void
    var playerItemObservation: NSKeyValueObservation?

    init(_ parent: VideoPlayerView, finishedPlaying: @escaping () -> Void) {
        self.parent = parent
        self.finishedPlaying = finishedPlaying
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEnd(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)

//        playerItemObservation = gPlayers[parent.index]?.currentItem?.observe(\.status, options: .new) { item, change in
//            switch item.status {
//                case .readyToPlay:
//                     break
//                    // Handle ready to play
//                case .failed: break
//                    // Handle failure
//                case .unknown: break
//                    // Handle unknown status
//                @unknown default: break
//                    // Handle other statuses
//            }
//        }
    }

    func updateObservation(for playerItem: AVPlayerItem?) {
        // Invalidate previous observation
        playerItemObservation?.invalidate()
        playerItemObservation = nil

        // Create new observation
        playerItemObservation = playerItem?.observe(\.status, options: .new) { item, change in
            iPrint("playerItemObservation: item.status: \(item.status)")
            switch item.status {
                case .readyToPlay: break
                case .failed: break
                    // Handle failure
                case .unknown: break
                    // Handle unknown status
                @unknown default: break
                    // Handle other statuses
            }
        }
    }

    @objc func playerItemFailedToPlayToEnd(_ notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            iPrint("Playback failed with error: \(error)")
            finishedPlaying()
        }
    }

    deinit {
        iPrint("VideoPlayerCoordinator: deinit")
        NotificationCenter.default.removeObserver(self)
        playerItemObservation?.invalidate()
    }
}

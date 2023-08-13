//import ObjectiveC
//import Foundation
import AVFoundation

class VideoPlayerCoordinator: NSObject {
    var parent: VideoPlayerView
    let finishedPlaying: () -> Void

    init(_ parent: VideoPlayerView, finishedPlaying: @escaping () -> Void) {
        self.parent = parent
        self.finishedPlaying = finishedPlaying
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEnd(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
    }

    @objc func playerItemFailedToPlayToEnd(_ notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            print("Playback failed with error: \(error)")
            finishedPlaying()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

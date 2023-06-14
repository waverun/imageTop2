import AVFoundation
import AppKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    let index: Int
    let finishedPlaying: () -> Void

    func makeNSView(context: Context) -> NSView {
        print("videoPlayerView \(url.path) on \(index)")
        let view = NSView()

        // create an AVPlayer
        let player = AVPlayer(url: url)

        // create a player layer
        let playerLayer = AVPlayerLayer(player: player)

        // Add observer to get notified when the video finishes playing
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            print("Video finished playing. \(self.index)")
            finishedPlaying()
            // You could do additional things here like play the next video, show a replay button, etc.
        }

        // make the player layer the same size as the view
        playerLayer.frame = view.bounds

        // make the player layer maintain its aspect ratio, and fill the view
        playerLayer.videoGravity = .resizeAspectFill

        // add the player layer to the view's layer
        view.layer = playerLayer

        // play the video
        player.play()
        print("Video started playing. \(self.index)")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let playerLayer = nsView.layer as? AVPlayerLayer,
              let player = playerLayer.player else {
            return
        }

        // Check if the player's URL is different from the new URL
        if let currentURL = player.currentItem?.asset as? AVURLAsset, currentURL.url != url {
            // Remove observer from current item
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

            // Replace the player's current item with a new AVPlayerItem
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)

            // Add observer to new item
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                print("Video finished playing. \(self.index)")
                finishedPlaying()
            }

            // Play the video
            player.play()
            print("Video started playing. \(self.index)")
        }
    }
}

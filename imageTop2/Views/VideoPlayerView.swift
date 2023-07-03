import AVFoundation
import AppKit
import SwiftUI

var gPlayers: [Int: AVPlayer] = [:]
var gTimers: [Int: PausableTimer] = [:]

struct VideoPlayerView: NSViewRepresentable {
    @EnvironmentObject var appDelegate: AppDelegate

    let url: URL
    let index: Int
    let finishedPlaying: () -> Void

    func makeNSView(context: Context) -> NSView {
        print("videoPlayerView \(url.path) on \(index)")
        let view = NSView()

        // create an AVPlayer
        let player = AVPlayer(url: url)
        player .isMuted = true

        startGetVideoLengthTask(player: player, url: url)
//        getVideoLength(videoURL: url)

        gPlayers[index] = player
        // create a player layer
        let playerLayer = AVPlayerLayer(player: player)

        // Add observer to get notified when the video finishes playing
//        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
//            print("Video finished playing. \(self.index)")
//                finishedPlaying()
//            // You could do additional things here like play the next video, show a replay button, etc.
//        }

        // make the player layer the same size as the view
        playerLayer.frame = view.bounds

        // make the player layer maintain its aspect ratio, and fill the view
        playerLayer.videoGravity = .resizeAspectFill

        // add the player layer to the view's layer
        view.layer = playerLayer

        // play the video
        if appDelegate.showWindow {
            print("play: \(index) \(Date())")
            player.play()
            print("Video1 started playing. makeNSView \(self.index)")
        }
        return view
    }

    func setEndPlayNotification(player: AVPlayer) {
        gTimers.removeValue(forKey: index)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            print("Video finished playing. \(self.index)")
            finishedPlaying()
            // You could do additional things here like play the next video, show a replay button, etc.
        }
    }

    func getVideoLength(videoURL: URL) async throws -> CMTime {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        return duration
    }

    func startGetVideoLengthTask(player: AVPlayer, url: URL) {
        Task {
            do {
                let duration = try await getVideoLength(videoURL: url)
                print("Timer: \(index) Video duration: \(CMTimeGetSeconds(duration)) seconds")
                let iDuration = Int(CMTimeGetSeconds(duration))
                if iDuration > 4 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(iDuration - 2)) {
                    let pausableTimer = PausableTimer(index: index)
                    gTimers[index] = pausableTimer
                    pausableTimer.start(interval: TimeInterval(iDuration - 2)) {_ in
                        finishedPlaying()
                    }
                } else {
                    setEndPlayNotification(player: player)
                }
            } catch {
                print("Failed to get video duration: \(error)")
                setEndPlayNotification(player: player)
            }
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let playerLayer = nsView.layer as? AVPlayerLayer,
              let player = playerLayer.player else {
            return
        }

        // Check if the player's URL is different from the new URL
        if let currentURL = player.currentItem?.asset as? AVURLAsset, currentURL.url != url {
//            player.pause()
            // Remove observer from current item

            startGetVideoLengthTask(player: player, url: url)

            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

            // Replace the player's current item with a new AVPlayerItem
            let item = AVPlayerItem(url: url)
            
            player.replaceCurrentItem(with: item)

            // Add observer to new item
//            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
//                print("Video finished playing. \(self.index)")
//                    finishedPlaying()
//            }

            // Play the video
            if appDelegate.showWindow {
                player.play()
                print("Video1 started playing. updateNSView \(self.index)")
            }
        }
    }
}

import AVFoundation
import AppKit
import SwiftUI

var gPlayers: [Int: AVPlayer] = [:]
var gTimers: [Int: PausableTimer] = [:]

class VideoPlayerViewStateObjects: ObservableObject {
    @Published var pausableTimer : PausableTimer?
}

struct VideoPlayerView: NSViewRepresentable {
    @EnvironmentObject var appDelegate: AppDelegate
    @StateObject var stateObjects = VideoPlayerViewStateObjects()

    let url: URL
    let index: Int
    let finishedPlaying: () -> Void

    func makeNSView(context: Context) -> NSView {
        debugPrint("videoPlayerView \(index) \(url.path)")
        let view = NSView()

//        let url = URL(fileURLWithPath: "/Users/shyem/Downloads/pexels-camila-flores.mp4")
//        let url = URL(fileURLWithPath: "/Users/shyem/Movies/pexels-camila-flores.mp4")
//        let url = URL(fileURLWithPath: "/Users/shyem/Downloads/Library-1of4.mov")
        // create an AVPlayer

//        let playerItem = AVPlayerItem(url: url)

//        playerItem.preferredForwardBufferDuration = 0

        let player = AVPlayer(url: url)
//        let player = AVPlayer(playerItem: playerItem)
//        player.rate = 0.2
        player .isMuted = true

        startGetVideoLengthTask(player: player, url: url)
//        getVideoLength(videoURL: url)

        gPlayers[index] = player
        debugPrint("gPlayers[index]: \(index)")
        // create a player layer
        let playerLayer = AVPlayerLayer(player: player)

        // Add observer to get notified when the video finishes playing
//        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
//            debugPrint("Video finished playing. \(self.index)")
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
            player.play()
            debugPrint("Video1 started playing. \(self.index) url: \(url) makeNSView \(Date())")
        }
        return view
    }

    func setEndPlayNotification(player: AVPlayer) {
        gTimers.removeValue(forKey: index)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            debugPrint("Video finished playing. \(self.index)")
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
                debugPrint("Timer: \(index) Video duration: \(CMTimeGetSeconds(duration)) seconds")
                let iDuration = Int(CMTimeGetSeconds(duration))
                debugPrint("iDuration \(index) \(iDuration)")
                if iDuration > 4 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(iDuration - 2)) {
                    stateObjects.pausableTimer = PausableTimer(index: index)
                    gTimers[index] = stateObjects.pausableTimer
                    stateObjects.pausableTimer!.start(interval: TimeInterval(iDuration - 2)) {_ in
                        finishedPlaying()
                    }
                } else {
                    setEndPlayNotification(player: player)
                }
            } catch {
                debugPrint("Failed to get video duration: \(error)")
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
        if let currentURL = player.currentItem?.asset as? AVURLAsset, currentURL.url.path != url.path {
//            player.pause()
            // Remove observer from current item

            startGetVideoLengthTask(player: player, url: url)

            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

            // Replace the player's current item with a new AVPlayerItem
//            let url = URL(fileURLWithPath: "/Users/shyem/Movies/Library-(1).mov")
//            let url = URL(fileURLWithPath: "/Users/shyem/Downloads/Library-4of4.mov")

            let item = AVPlayerItem(url: url)

//            item.preferredForwardBufferDuration = 0

            player.replaceCurrentItem(with: item)
//            player.rate = 0.2
            // Add observer to new item
//            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
//                debugPrint("Video finished playing. \(self.index)")
//                    finishedPlaying()
//            }

            // Play the video
            if appDelegate.showWindow {
                player.play()
                debugPrint("Video1 started playing. \(self.index) url: \(url) updateNSView \(Date())")
            }
        }
    }
}

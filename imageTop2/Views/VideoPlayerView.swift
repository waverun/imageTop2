import AVFoundation
import AppKit
import SwiftUI

var gPlayers: [Int: AVPlayer] = [:]
var gPausableTimers: [Int: PausableTimer] = [:]
//var gVideoPlayerViewStateObjects: [Int:VideoPlayerViewStateObjects] = [:]
//
//struct VideoPlayerViewStateObjects {
//    var pausableTimer : PausableTimer?
//}

//class VideoPlayerViewStateObjects: ObservableObject {
//    @Published var pausableTimer : PausableTimer?
//}

struct VideoPlayerView: NSViewRepresentable {
    @EnvironmentObject var appDelegate: AppDelegate
//    @StateObject var stateObjects = VideoPlayerViewStateObjects()

    let url: URL
    let index: Int
    let finishedPlaying: () -> Void

    func makeNSView(context: Context) -> NSView {
        iPrint("videoPlayerView \(index) \(url.path)")
        let view = NSView()

        let player = AVPlayer(url: url)
        player .isMuted = true

        startGetVideoLengthTask(player: player, url: url)

        gPlayers[index] = player
        iPrint("gPlayers[index]: \(index)")
        // create a player layer
        let playerLayer = AVPlayerLayer(player: player)

        // make the player layer the same size as the view
        playerLayer.frame = view.bounds

        // make the player layer maintain its aspect ratio, and fill the view
        playerLayer.videoGravity = .resizeAspectFill

        // add the player layer to the view's layer
        view.layer = playerLayer

        // play the video
        if appDelegate.showWindow {
            player.play()
            iPrint("Video1 started playing. \(index) url: \(url) makeNSView \(Date())")
        }

#if DEBUG
        iPrint("Memory: \(index) Play makeNSView: \(reportMemory())")
#endif

        return view
    }

    func setEndPlayNotification(player: AVPlayer) {
        gPausableTimers.removeValue(forKey: index)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            iPrint("Video finished playing. \(index)")
            startNewVideo(player)
            // You could do additional things here like play the next video, show a replay button, etc.
        }
    }

    func getVideoLength(videoURL: URL) async throws -> CMTime {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        return duration
    }

    func startGetVideoLengthTask(player: AVPlayer, url: URL) {
        iPrint("startGetVideoLengthTask: \(index) url: \(url)")
        Task {
            do {
                let duration = try await getVideoLength(videoURL: url)
                iPrint("Timer: \(index) Video duration: \(CMTimeGetSeconds(duration)) seconds")
                let iDuration = Int(CMTimeGetSeconds(duration))
                iPrint("iDuration \(index) \(iDuration)")
                if iDuration > 4 {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(iDuration - 2)) {
                    if let timer = gPausableTimers[index] {
                        timer.invalidate()
                        gPausableTimers[index] = nil
                    }
                    gPausableTimers[index] = PausableTimer(index: index)
//                    gPausableTimers[index] = gVideoPlayerViewStateObjects[index]?.pausableTimer
                    gPausableTimers[index]?.start(interval: TimeInterval(iDuration - 2)) { _ in
                        startNewVideo(player)
                    }
                } else {
                    setEndPlayNotification(player: player)
                }
            } catch {
                iPrint("Failed to get video duration: \(error)")
                setEndPlayNotification(player: player)
            }
        }
    }

    func startNewVideo(_ player: AVPlayer) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        gPausableTimers[index]?.invalidate()
        finishedPlaying()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let playerLayer = nsView.layer as? AVPlayerLayer,
              let player = playerLayer.player else {
            return
        }

        // Check if the player's URL is different from the new URL
        if let currentURL = player.currentItem?.asset as? AVURLAsset, currentURL.url.path != url.path {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

            let item = AVPlayerItem(url: url)

            player.replaceCurrentItem(with: item)

            startGetVideoLengthTask(player: player, url: url)

            // Play the video
            if appDelegate.showWindow {
                player.play()
                iPrint("Video1 started playing. \(index) url: \(url) updateNSView \(Date())")
            }
#if DEBUG
            iPrint("Memory: \(index) Play updateNSView: \(reportMemory())")
#endif
        }
    }
}

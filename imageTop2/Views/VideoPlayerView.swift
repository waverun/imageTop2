import AVFoundation
import AppKit
import SwiftUI

var gPlayers = ThreadSafeDict<Int, AVPlayer>()
//var gPlayers: [Int: AVPlayer] = [:]
var gVideoFailedToPlay = ThreadSafeDict<Int, VideoFailedToPlay>()
//var gVideoFailedToPlay: [Int: VideoFailedToPlay] = [:]
var gPausableTimers = ThreadSafeDict<Int, PausableTimer>()
//var gPausableTimers: [Int: PausableTimer] = [:]
var gVideoLengthTasks = ThreadSafeDict<Int, Task<Void, Never>>()
//var gVideoLengthTasks: [Int: Task<Void, Never>] = [:]
var gEndPlayNotifications = ThreadSafeDict<Int, NSObjectProtocol>()
//var gEndPlayNotifications: [Int: NSObjectProtocol] = [:]
var gNeedToLoadImageOrVideo = ThreadSafeDict<Int, Bool>()
//var gNeedToLoadImageOrVideo: [Int: Bool] = [:]

class VideoFailedToPlay {
    var playerItem: AVPlayerItem
    var index: Int
    var finishedPlaying: () -> Void

    init(playerItem: AVPlayerItem, index: Int, finishedPlaying: @escaping () -> Void) {
        // Add an observer for the AVPlayerItemFailedToPlayToEndTimeNotification notification
        self.playerItem = playerItem
        self.index = index
        self.finishedPlaying = finishedPlaying

        NotificationCenter.default.addObserver(self, selector: #selector(videoFailedToPlay), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }

    @objc func videoFailedToPlay(notification: Notification) {
        // Check the error
//        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            var url = ""
            if let urlAsset = playerItem.asset as? AVURLAsset {
                url = urlAsset.url.absoluteString
            }
            iPrint("videoFailedToPlay: currentTime: \(playerItem.currentTime().seconds) url: \(url)")
            finishedPlaying()
            // Handle the error or display a notification to the user
//            displayNotification(with: "Video Playback Error", informativeText: error.localizedDescription)
        }
//    }
}

struct VideoPlayerView: NSViewRepresentable {
    @EnvironmentObject var appDelegate: AppDelegate

    let url: URL
    let index: Int
    let finishedPlaying: () -> Void

    func makeNSView(context: Context) -> NSView {
        iPrint("videoPlayerView \(index) \(url.path)")
        let view = NSView()

        let player = AVPlayer(url: url)
        player .isMuted = true

        startGetVideoLength(player: player, url: url)

        iPrint("makeNSView: \(index) gPausableTimers.count: \(gPausableTimers.count)")
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

//        context.coordinator.updateObservation(for: player.currentItem)

        guard let playerItem = player.currentItem else {
            iPrint("makeNSView: \(index) couldn't get playerItem url: \(url)")
            return view
        }

        gVideoFailedToPlay[index] = VideoFailedToPlay(playerItem: playerItem, index: index, finishedPlaying: finishedPlaying)

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

//    func makeCoordinator() -> VideoPlayerCoordinator {
//        return VideoPlayerCoordinator(self, finishedPlaying: finishedPlaying)
//    }

    func setEndPlayNotification(player: AVPlayer) {
//        gPausableTimers.removeValue(forKey: index)
        if let endPlayNotification = gEndPlayNotifications[index] {
            NotificationCenter.default.removeObserver(endPlayNotification)
        }
        gEndPlayNotifications[index] = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            if let startGetVideoLengthTask = gVideoLengthTasks[index] {
                startGetVideoLengthTask.cancel()
            }
#if DEBUG
            var url = ""
            if let urlAsset = player.currentItem?.asset as? AVURLAsset {
                url = urlAsset.url.absoluteString
            }
            iPrint("Video finished playing. \(index) url: \(url)")
#endif
            startNewVideo(player)
            // You could do additional things here like play the next video, show a replay button, etc.
        }
    }

    func getVideoLength(videoURL: URL) async throws -> CMTime {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        return duration
    }

    func startGetVideoLength(player: AVPlayer, url: URL) {
        iPrint("startGetVideoLengthTask: \(index) url: \(url)")
        if let startGetVideoLengthTask = gVideoLengthTasks[index] {
            startGetVideoLengthTask.cancel()
        }
        gVideoLengthTasks[index] = Task {
            do {
                iPrint("startGetVideoLength: \(index) await before url: \(url)")
                let duration = try await getVideoLength(videoURL: url)
                iPrint("startGetVideoLength: \(index) await after url: \(url)")
                iPrint("Timer: \(index) Video duration: \(CMTimeGetSeconds(duration)) seconds")
                let iDuration = Int(CMTimeGetSeconds(duration))
                iPrint("iDuration \(index) \(iDuration) url: \(url)")
                if iDuration > 4 {
                    if let timer = gPausableTimers[index] {
                        timer.invalidate()
                        gPausableTimers[index] = nil
                    }
                    gPausableTimers[index] = PausableTimer(index: index)
                    iPrint("startGetVideoLength: \(index) before start: gPausableTimers.count \(gPausableTimers.count)")
                    gPausableTimers[index]?.start(interval: TimeInterval(iDuration - 2)) { _ in
                        iPrint("in PausableTimer: \(index)")
                        if let endPlayNotification = gEndPlayNotifications[index] {
                            NotificationCenter.default.removeObserver(endPlayNotification)
                        }
                        startNewVideo(player)
                    }
                    iPrint("startGetVideoLength: \(index) afterStart: gPausableTimers.count  \(gPausableTimers.count)")
                }
//                else {
//                    setEndPlayNotification(player: player)
//                }
            }
            catch {
                iPrint("Failed to get video duration: \(error)")
                iPrint("startGetVideoLength: error: \n\(error) \nurl: \(url)")
//                setEndPlayNotification(player: player)
            }

//            setEndPlayNotification(player: player) // Always set end of play notification to prevent stacks

            if let videoLengthTask = gVideoLengthTasks[index],
               videoLengthTask.isCancelled {
                return
            }
        }
    }

    func startNewVideo(_ player: AVPlayer) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        gPausableTimers[index]?.invalidate()
        finishedPlaying()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        iPrint("updateNSView: \(index) gPausableTimers.count: \(gPausableTimers.count)")
        guard let playerLayer = nsView.layer as? AVPlayerLayer,
              let player = playerLayer.player else {
            iPrint("updateNSView: \(index) Couldn't get player. url: \(url)")
            return
        }

        // Check if the player's URL is different from the new URL
        if let currentURL = player.currentItem?.asset as? AVURLAsset, currentURL.url.path != url.path {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

            iPrint("updateNSView: \(index) currentURL: \(currentURL)")
            iPrint("updateNSView: \(index) Creating new item for url: \(url)")

            let player = AVPlayer(url: url)
            player.isMuted = true

            gPlayers[index] = player
            playerLayer.removeAllAnimations()
            playerLayer.player = nil
            playerLayer.player = player
//            gPlayers[index] = player
//
//            let item = AVPlayerItem(url: url)
//
//            player.replaceCurrentItem(with: item)

//            context.coordinator.updateObservation(for: item)

//            gVideoFailedToPlay[index] = VideoFailedToPlay(playerItem: item, index: index, finishedPlaying: finishedPlaying)

            guard let playerItem = player.currentItem else {
                iPrint("makeNSView: \(index) couldn't get playerItem url: \(url)")
                return
            }
            
            gVideoFailedToPlay[index] = VideoFailedToPlay(playerItem: playerItem, index: index, finishedPlaying: finishedPlaying)

            startGetVideoLength(player: player, url: url)

            // Play the video
            switch true {
                case appDelegate.showWindow:
                    player.play()
                    iPrint("Video1 started playing. \(index) url: \(url) updateNSView \(Date())")
                default: gPausableTimers[index]?.pause()
            }
#if DEBUG
            iPrint("Memory: \(index) Play updateNSView: \(reportMemory())")
#endif
        }
    }
}

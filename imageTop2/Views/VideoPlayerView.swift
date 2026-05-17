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
let videoFadeLeadTime: TimeInterval = 4.0
let videoDurationSafetyMargin: TimeInterval = 1.0

class VideoFailedToPlay {
    var playerItem: AVPlayerItem
    var index: Int
    var finishedPlaying: () -> Void
    private var issueCheckWorkItem: DispatchWorkItem?
    private var didTriggerTransition = false
    private let failureGraceDelay: TimeInterval = 2.0
    private let failureCheckInterval: TimeInterval = 0.3
    private let minimumProgressToContinue: Double = 0.01
    
    private func playerItemDurationSeconds() -> Double {
        let seconds = CMTimeGetSeconds(playerItem.duration)
        return seconds.isFinite ? seconds : -1
    }

    init(playerItem: AVPlayerItem, index: Int, finishedPlaying: @escaping () -> Void) {
        // Add observers for playback failure and playback stall.
        self.playerItem = playerItem
        self.index = index
        self.finishedPlaying = finishedPlaying

        NotificationCenter.default.addObserver(self, selector: #selector(videoFailedToPlay), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(videoPlaybackStalled), name: .AVPlayerItemPlaybackStalled, object: playerItem)
    }

    deinit {
        issueCheckWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func videoFailedToPlay(notification: Notification) {
        var url = ""
        if let urlAsset = playerItem.asset as? AVURLAsset {
            url = urlAsset.url.absoluteString
        }
        iPrint("videoFailedToPlay: currentTime: \(playerItem.currentTime().seconds) url: \(url)")
        handlePlaybackIssue(reason: "failedToPlay")
    }

    @objc func videoPlaybackStalled(notification: Notification) {
        var url = ""
        if let urlAsset = playerItem.asset as? AVURLAsset {
            url = urlAsset.url.absoluteString
        }
        let stalledTime = playerItem.currentTime().seconds
        iPrint("videoPlaybackStalled: currentTime: \(stalledTime) url: \(url)")

        playerItem.seek(to: playerItem.currentTime()) { _ in }
        handlePlaybackIssue(reason: "playbackStalled")
    }

    private func handlePlaybackIssue(reason: String) {
        if didTriggerTransition {
            return
        }
        issueCheckWorkItem?.cancel()
        let issueTime = playerItem.currentTime().seconds
        let startWallTime = Date().timeIntervalSince1970
        scheduleIssueCheck(reason: reason, issueTime: issueTime, delay: failureCheckInterval, startWallTime: startWallTime)
    }
    
    private func scheduleIssueCheck(reason: String, issueTime: Double, delay: TimeInterval, startWallTime: TimeInterval) {
        let nextCheck = DispatchWorkItem { [weak self] in
            self?.handlePlaybackIssueContinuation(reason: reason, issueTime: issueTime, startWallTime: startWallTime)
        }
        issueCheckWorkItem = nextCheck
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: nextCheck)
    }
    
    private func handlePlaybackIssueContinuation(reason: String, issueTime: Double, startWallTime: TimeInterval) {
        if didTriggerTransition {
            return
        }
        let currentTime = playerItem.currentTime().seconds
        let progressed = (currentTime - issueTime) > minimumProgressToContinue
        if progressed {
            let remainingGrace = max(0, failureGraceDelay - (Date().timeIntervalSince1970 - startWallTime))
            iPrint("handlePlaybackIssue: progress after \(reason). index: \(index) progressed: \(currentTime - issueTime) remainingGrace: \(remainingGrace)")
            if remainingGrace > 0 {
                scheduleIssueCheck(reason: reason, issueTime: issueTime, delay: min(failureCheckInterval, remainingGrace), startWallTime: startWallTime)
            }
            return
        }
        let elapsedWallTime = Date().timeIntervalSince1970 - startWallTime
        if elapsedWallTime < failureGraceDelay {
            scheduleIssueCheck(reason: reason, issueTime: issueTime, delay: min(failureCheckInterval, failureGraceDelay - elapsedWallTime), startWallTime: startWallTime)
            return
        }
        didTriggerTransition = true
        iPrint("handlePlaybackIssue: transition after \(reason). index: \(index) currentTime: \(currentTime) duration: \(playerItemDurationSeconds())")
        finishedPlaying()
    }
}

struct VideoPlayerView: NSViewRepresentable {
    @EnvironmentObject var appDelegate: AppDelegate

    let url: URL
    let index: Int
    let finishedPlaying: () -> Void

    func logVideoTiming(_ label: String, playerItem: AVPlayerItem?, player: AVPlayer?) {
        let durationSeconds = CMTimeGetSeconds(playerItem?.duration ?? .zero)
        let currentSeconds = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        let normalizedDuration = durationSeconds.isFinite ? durationSeconds : -1
        let normalizedCurrent = currentSeconds.isFinite ? currentSeconds : -1
        iPrint("\(label) index: \(index) currentTime: \(normalizedCurrent) duration: \(normalizedDuration) url: \(url)")
    }

    func makeNSView(context: Context) -> NSView {
        iPrint("videoPlayerView \(index) \(url.path)")
        let view = NSView()

        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 12
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = true

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
//            player.play()
            play(player)
            iPrint("Video1 started playing. \(index) url: \(url) makeNSView \(Date())")
        }
        logVideoTiming("Video timing on start", playerItem: player.currentItem, player: player)

#if DEBUG
        iPrint("Memory: \(index) Play makeNSView: \(reportMemory())")
#endif
        return view
    }

    func play(_ player: AVPlayer) {
        player.play()
        // Retry play once to handle occasional remote stream startup stalls.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if player.timeControlStatus != .playing {
                player.play()
            }
        }
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
            logVideoTiming("Video timing on end", playerItem: player.currentItem, player: player)
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
            //            do {
            iPrint("startGetVideoLength: \(index) await before url: \(url)")
            var duration : CMTime = .zero
            do {
                duration = try await getVideoLength(videoURL: url)
            }
            catch {
                iPrint("Failed to get video duration: \(error)")
                iPrint("startGetVideoLength: error: \n\(error) \nurl: \(url)")
                //                setEndPlayNotification(player: player)
            }

            iPrint("startGetVideoLength: \(index) await after url: \(url)")
            iPrint("Timer: \(index) Video duration: \(CMTimeGetSeconds(duration)) seconds")
            let iDuration = CMTimeGetSeconds(duration)
            iPrint("iDuration \(index) \(iDuration) url: \(url)")
            logVideoTiming("Video timing after duration load", playerItem: player.currentItem, player: player)
            if iDuration.isFinite, iDuration > (videoFadeLeadTime + videoDurationSafetyMargin) {
                if let timer = gPausableTimers[index] {
                    timer.invalidate()
                    gPausableTimers[index] = nil
                }
                gPausableTimers[index] = PausableTimer(index: index)
                iPrint("startGetVideoLength: \(index) before start: gPausableTimers.count \(gPausableTimers.count)")
                gPausableTimers[index]?.start(interval: TimeInterval(max(0, iDuration - videoFadeLeadTime - videoDurationSafetyMargin))) { _ in
                    let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
                    let normalizedCurrentTime = playerCurrentTime.isFinite ? playerCurrentTime : 0
                    let mediaTimeRemaining = iDuration - normalizedCurrentTime - videoFadeLeadTime - videoDurationSafetyMargin
                    if mediaTimeRemaining > 0.15 {
                        iPrint("in PausableTimer: \(index) fired early. currentTime: \(normalizedCurrentTime) duration: \(iDuration) remainingMediaTime: \(mediaTimeRemaining)")
                        gPausableTimers[index]?.start(interval: mediaTimeRemaining) { _ in
                            iPrint("in PausableTimer: \(index) delayed media-time switch")
                            if let endPlayNotification = gEndPlayNotifications[index] {
                                NotificationCenter.default.removeObserver(endPlayNotification)
                            }
                            startNewVideo(player)
                        }
                        return
                    }
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
        //            catch {
        //                iPrint("Failed to get video duration: \(error)")
        //                iPrint("startGetVideoLength: error: \n\(error) \nurl: \(url)")
        ////                setEndPlayNotification(player: player)
        //            }

        //            setEndPlayNotification(player: player) // Always set end of play notification to prevent stacks

        //            if let videoLengthTask = gVideoLengthTasks[index],
        //               videoLengthTask.isCancelled {
        //                return
        //            }
        //        }
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

            let playerItem = AVPlayerItem(url: url)
            playerItem.preferredForwardBufferDuration = 12
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
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
//                    player.play()
                    play(player)
                    iPrint("Video1 started playing. \(index) url: \(url) updateNSView \(Date())")
                default: gPausableTimers[index]?.pause()
            }
            logVideoTiming("Video timing on update start", playerItem: player.currentItem, player: player)
#if DEBUG
            iPrint("Memory: \(index) Play updateNSView: \(reportMemory())")
#endif
        }
    }
}

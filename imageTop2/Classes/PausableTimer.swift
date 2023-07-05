import Foundation
import AVFoundation

class PausableTimer {
    private var timer: Timer?
    private var startTime: Date?
    private var timeElapsedWhenPaused: TimeInterval = 0
    private var interval: TimeInterval = 0
    private var block: ((Timer) -> Void)?
    var index: Int?

    init (index: Int) {
        self.index = index
    }

    func start(interval: TimeInterval, block: @escaping (Timer) -> Void) {
        debugPrint("timer: \(index!) start \(interval)")
        self.interval = interval
        self.block = block
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: block)
    }

    func pause() {
        timeElapsedWhenPaused = -startTime!.timeIntervalSinceNow
        debugPrint("timer: \(index!) pause: \(timeElapsedWhenPaused)")
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        startTime = Date()
        debugPrint("timer: \(index!) resume: \(interval) \(timeElapsedWhenPaused)")

        interval = interval - timeElapsedWhenPaused
        if interval <= 0,
           let block = block,
           let timer = timer {
            block(timer)
            return
        }

        if let currentTime = gPlayers[index!]?.currentTime(),
           let duration = gPlayers[index!]?.currentItem?.duration {

           let playerCurrentTimeSec = CMTimeGetSeconds(currentTime)
           let playerDurationSec = CMTimeGetSeconds(duration)

           debugPrint("timer: \(index!) resume: currentTime: \(playerCurrentTimeSec)")

           let remainingTimeSec = playerDurationSec - playerCurrentTimeSec
           interval = remainingTimeSec
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: block!)
        debugPrint("timer: \(index!) resume: \(interval)")
//        { [weak self] timer in
//            self?.start(interval: self!.timeElapsedWhenPaused, block: self!.block!)
//        }
    }
}

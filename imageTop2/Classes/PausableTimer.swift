import Foundation
import AVFoundation

class PausableTimer {
    var timer: Timer?
    var startTime: Date?
    var timeElapsedWhenPaused: TimeInterval = 0
    var interval: TimeInterval = 0
    var block: ((Timer?) -> Void)?
    var index: Int?

    init (index: Int) {
        self.index = index
    }

    deinit {
        invalidate()
    }

    func start(interval: TimeInterval, block: @escaping (Timer?) -> Void) {
        iPrint("timer: \(index!) start \(interval)")
        self.interval = interval
        self.block = block
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: block)
    }

    func pause() {
        timeElapsedWhenPaused = -startTime!.timeIntervalSinceNow
        iPrint("timer: \(index!) pause: \(timeElapsedWhenPaused)")
        timer?.invalidate()
        timer = nil
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        startTime = Date()
        iPrint("timer: \(index!) resume: \(interval) \(timeElapsedWhenPaused)")

        interval = interval - timeElapsedWhenPaused
        guard interval > 0,
              let currentTime = gPlayers[index!]?.currentTime(),
              let duration = gPlayers[index!]?.currentItem?.duration else {
            if let block = block {
                block(timer)
            }
            return
        }

        let playerCurrentTimeSec = CMTimeGetSeconds(currentTime)
        let playerDurationSec = CMTimeGetSeconds(duration)

        iPrint("timer: \(index!) resume: currentTime: \(playerCurrentTimeSec)")

        let remainingTimeSec = playerDurationSec - playerCurrentTimeSec
        interval = remainingTimeSec

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: block!)
        iPrint("timer: \(index!) resume: \(interval)")
    }
}

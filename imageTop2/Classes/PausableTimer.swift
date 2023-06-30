import Foundation

class PausableTimer {
    private var timer: Timer?
    private var startTime: Date?
    private var timeElapsedWhenPaused: TimeInterval = 0

    func start(interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
    }

    func pause() {
        timeElapsedWhenPaused = -startTime!.timeIntervalSinceNow
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        startTime = Date().addingTimeInterval(-timeElapsedWhenPaused)
        timer = Timer.scheduledTimer(withTimeInterval: -startTime!.timeIntervalSinceNow, repeats: false) { [weak self] timer in
            self?.start(interval: self!.timeElapsedWhenPaused, repeats: false, block: { _ in })
        }
    }
}

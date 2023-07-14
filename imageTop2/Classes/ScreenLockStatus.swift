class ScreenLockStatus {
    static let shared = ScreenLockStatus()

    var isLocked: Bool = false

     init() { } //  initialization to ensure just one instance is created.
}

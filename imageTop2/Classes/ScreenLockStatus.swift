class ScreenLockStatus {
    static let shared = ScreenLockStatus()

    var isLocked: Bool = false

    private init() { } // private initialization to ensure just one instance is created.
}

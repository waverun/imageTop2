func debugdebugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    debugPrint(items, separator: separator, terminator: terminator)
#endif
}

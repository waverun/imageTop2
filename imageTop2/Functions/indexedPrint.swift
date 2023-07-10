var debugIndex = 0

func iPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    debugPrint("\(debugIndex):", terminator: " ")
    debugPrint(items, separator: separator, terminator: terminator)
    debugIndex += 1
}

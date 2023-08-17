
extension String {
    func unCapcase() -> String {
        let firstCharLowercased = self.prefix(1).lowercased()
        let restOfString = self.dropFirst()
        let finalString = firstCharLowercased + restOfString
        return finalString
    }
}

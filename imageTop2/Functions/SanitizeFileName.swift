import Foundation

func sanitizeFileName(_ name: String) -> String {
    let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    return name.components(separatedBy: illegalCharacters).joined(separator: "_")
}

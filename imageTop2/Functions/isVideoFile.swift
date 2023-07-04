import UniformTypeIdentifiers

func isVideoFile(atPath path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
          let uti = UTType(typeIdentifier) else {
        return false
    }

    return uti.conforms(to: .movie)
}

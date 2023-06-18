import Foundation

func clearPexelVideos(folderURL: URL, fileName: String) {
    let fileURL = folderURL.appendingPathComponent(fileName)
    deleteFile(at: fileURL)
}

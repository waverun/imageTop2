import Foundation

func clearPexelVideos(folderURL: URL, fileName: String) {
    var fileURL = folderURL.appendingPathComponent(fileName)
    deleteFile(at: fileURL)
}

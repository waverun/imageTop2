import Foundation

func                     clearPexelPhotos(folderPath: String, filesToKeep: [String]) {
    do {
        let directoryURL = URL(fileURLWithPath: folderPath)
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        for fileURL in contents {
            if !filesToKeep.contains(fileURL.lastPathComponent) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    } catch {
        // Handle the error.
        debugPrint("Error clearing directory: \(error)")
    }
}
